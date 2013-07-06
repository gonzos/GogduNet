package gogduNet.sockets
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ServerSocketConnectEvent;
	import flash.events.TimerEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import gogduNet.utils.ObjectPool;
	import gogduNet.utils.RandomID;
	
	import gogduNet.events.GogduNetDataEvent;
	import gogduNet.events.GogduNetSocketEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.sockets.GogduNetSocket;
	import gogduNet.utils.Encryptor;
	import gogduNet.utils.RecordConsole;
	
	/** 허용되지 않은 대상에게서 정보가 전송되면 발생 */
	[Event(name="unpermittedConnection", type="gogduNet.events.GogduNetSocketEvent")]
	/** 운영체제 등에 의해 비자발적으로 연결이 끊긴 경우 발생 */
	[Event(name="close", type="flash.events.Event")]
	/** 특정 소켓이 성공적으로 접속한 경우 발생 */
	[Event(name="connect", type="gogduNet.events.GogduNetSocketEvent")]
	/** 특정 소켓의 연결 시도가 실패한 경우 발생 */
	[Event(name="connectFailed", type="gogduNet.events.GogduNetSocketEvent")]
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetSocketEvent")]
	/** 특정 소켓의 연결이 끊긴 경우 발생 */
	[Event(name="close", type="gogduNet.events.GogduNetSocketEvent")]
	/** 데이터를 완전히 수신했을 때 발생. 데이터는 이벤트로 전달된다. */
	[Event(name="receiveData", type="gogduNet.events.GogduNetDataEvent")]
	/** 데이터를 전송 받는 중일 때 발생. 지금까지 전송 받은 데이터가 이벤트로 전달된다.
	 * (dataDefinition 속성이 존재하면 사용자가 보낸 (헤더와 프로토콜을 제외한)실질적인 데이터의 전송 상태를
	 * data 속성으로 전달하며, dataDefinition 속성이 존재하지 않으면(null)
	 * 아직 헤더나 프로토콜이 다 전송되지 않은 걸 의미하며, 헤더와 프로토콜이 포함된 바이트 배열이 전달된다)</br>
	 * (데이터의 크기가 적어 너무 빨리 다 받은 경우엔 이 이벤트가 발생하지 않을 수도 있다.)*/
	[Event(name="progressData", type="gogduNet.events.GogduNetDataEvent")]
	/** 정상적이지 않은 데이터를 수신했을 때 발생 */
	//[Event(name="invalidPacket", type="gogduNet.events.GogduNetDataEvent")]
	
	/** <p>2진 데이터 전송용 TCP 서버. 파일을 전송하는 데에 쓸 수 있다.</p>
	 * <strong>패킷의 형태</strong>
	 * <p>굳이 알 필요는 없지만, 조금 수정해서 사용할 거라면 참고.</p>
	 * <p>Data Type은 DataType.BYTES로 고정.</p>
	 * <p>4 byte - 4 byte - variable(가변적) byte - variable byte</p>
	 * 	<ol>
	 * 		<li>4 byte (uint) : data size</li>
	 * 		<li>4 byte (uint) : protocol length</li>
	 * 		<li>variable byte : protocol string (protocol length 만큼의 길이를 가진다)</li>
	 * 		<li>variable byte : data (헤더와 프로토콜(definition)을 포함하지 않은 데이터. data size 만큼의 길이를 가진다)</li>
	 * 	</ol>
	 */
	public class GogduNetBinaryServer extends EventDispatcher
	{
		private var _timer:Timer;
		
		// 서버 설정
		/** 최대 연결 지연 한계 **/
		private var _connectionDelayLimit:Number;
		
		/** 서버 소켓 */
		private var _serverSocket:ServerSocket;
		/** 서버 address */
		private var _serverAddress:String;
		/** 서버 포트 */
		private var _serverPort:int;
		/** 서버 인코딩 유형(기본값="UTF-8") */
		private var _encoding:String;
		
		// 서버 상태
		/** 서버가 실행 중인지를 나타내는 bool 값 */
		private var _run:Boolean;
		/** 서버가 시작된 지점의 시간을 나타내는 변수 */
		private var _runnedTime:Number;
		/** 마지막으로 통신한 시각(정확히는 마지막으로 정보를 전송 받은 시각) */
		private var _lastReceivedTime:Number;
		/** 최대 인원 */
		private var _maxSockets:uint;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		/** 클라이언트 소켓 배열 */
		private var _socketArray:Vector.<GogduNetSocket>;
		/** 소켓 객체의 id를 주소값으로 사용하여 저장하는 객체 */
		private var _idTable:Object;
		
		private var _event:GogduNetSocketEvent;
		
		/** 중복되지 않는 ID를 발급해 주는 RandomID 객체 */
		private var _randomID:RandomID;
		/** 소켓용 풀 */
		private var _socketPool:ObjectPool;
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체 */
		private var _connectionSecurity:GogduNetConnectionSecurity;
		
		/** <p>serverAddress : 서버로 사용할 address</p>
		 * <p>serverPort : 서버로 사용할 포트</p>
		 * <p>maxSockets : 최대 인원 수 제한</p>
		 * <p>timerInterval : 정보 수신과 연결 검사를 할 때 사용할 타이머의 반복 간격(ms)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(ms)(여기서 설정한 시간 동안 소켓으로부터 데이터가 오지 않으면 그 소켓과는 연결이 끊긴 것으로 간주한다.)</p>
		 * <p>encoding : 프로토콜 문자열의 변환에 사용할 인코딩 형식</p>
		 */
		public function GogduNetBinaryServer(serverAddress:String="0.0.0.0", serverPort:int=0, maxSockets:uint=10, connectionSecurity:GogduNetConnectionSecurity=null, timerInterval:Number=100,
									   connectionDelayLimit:Number=10000, encoding:String="UTF-8")
		{
			_timer = new Timer(timerInterval);
			_connectionDelayLimit = connectionDelayLimit;
			_serverSocket = new ServerSocket();
			_serverAddress = serverAddress;
			_serverPort = serverPort;
			_encoding = encoding;
			_run = false;
			_runnedTime = -1;
			_lastReceivedTime = -1;
			_maxSockets = maxSockets;
			_record = new RecordConsole();
			_socketArray = new Vector.<GogduNetSocket>();
			_idTable = new Object();
			_event = new GogduNetSocketEvent(GogduNetSocketEvent.CONNECTION_UPDATED, false, false, null, null, null);
			_randomID = new RandomID();
			_socketPool = new ObjectPool(GogduNetSocket);
			
			if(connectionSecurity == null)
			{
				connectionSecurity = new GogduNetConnectionSecurity(false);
			}
			_connectionSecurity = connectionSecurity;
		}
		
		/** 서버 실행용 타이머의 재생 간격을 가져온다. */
		public function get timerInterval():Number
		{
			return _timer.delay;
		}
		/** 서버 실행용 타이머의 재생 간격을 설정한다. */
		public function set timerInterval(value:Number):void
		{
			_timer.delay = value;
		}
		
		/** 연결 지연 한계를 가져온다.(ms) */
		public function get connectionDelayLimit():Number
		{
			return _connectionDelayLimit;
		}
		/** 연결 지연 한계를 설정한다.(ms) */
		public function set connectionDelayLimit(value:Number):void
		{
			_connectionDelayLimit = value;
		}
		
		// setter, getter
		/** 소켓을 가져온다. */
		public function get serverSocket():ServerSocket
		{
			return _serverSocket;
		}
		
		/** 서버의 address를 가져오거나 설정한다. 설정은 서버가 실행되고 있지 않을 때에만 할 수 있다. */
		public function get address():String
		{
			return _serverAddress;
		}
		public function set address(value:String):void
		{
			if(_run == true)
			{
				return;
			}
			
			_serverAddress =value;
		}
		
		/** 서버의 포트를 가져오거나 설정한다. 설정은 서버가 실행되고 있지 않을 때에만 할 수 있다. */
		public function get port():int
		{
			return _serverPort;
		}
		public function set port(value:int):void
		{
			if(_run == true)
			{
				return;
			}
			
			_serverPort =value;
		}
		
		/** 서버의 통신 인코딩 유형을 가져오거나 설정한다. 설정은 서버가 실행되고 있지 않을 때에만 할 수 있다. */
		public function get encoding():String
		{
			return _encoding;
		}
		public function set encoding(value:String):void
		{
			if(_run == true)
			{
				return;
			}
			
			_encoding =value;
		}
		
		/** 서버가 실행 중인지를 나타내는 값을 가져온다. */
		public function get isRunning():Boolean
		{
			return _run;
		}
		
		/** 서버의 최대 인원 제한 수를 가져오거나 설정한다. (이 값은 새로 들어오는 연결에만 영향을 주며, 기존 연결은 끊어지지 않는다.)*/
		public function get maxSockets():uint
		{
			return _maxSockets;
		}
		public function set maxSockets(value:uint):void
		{
			_maxSockets =value;
		}
		
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체를 가져오거나 설정한다. */
		public function get connectionSecurity():GogduNetConnectionSecurity
		{
			return _connectionSecurity;
		}
		public function set connectionSecurity(value:GogduNetConnectionSecurity):void
		{
			_connectionSecurity = value;
		}
		
		/** 서버의 현재 인원을 가져온다. */
		public function get currentSockets():uint
		{
			return _socketArray.length;
		}
		
		/** 디버그용 기록을 가져온다. 사용자가 명시적으로 RecordConsole.clear() 함수를 실행하는 경우를 제외하면,
		 * 이 기록은 서버를 닫거나 서버를 다시 시작해도 그대로 남아있다.
		 * */
		public function get record():RecordConsole
		{
			return _record;
		}
		
		/** 소켓에게 id를 발급해 주는 RandomID 타입의 객체를 가져온다. 서버를 닫을 경우 RandomID.clear() 함수로 초기화된다. */
		public function get idIssuer():RandomID
		{
			return _randomID;
		}
		
		/** 소켓용 Object Pool이다. 서버를 닫을 경우 ObjectPool.clear() 함수로 초기화된다. */
		public function get socketPool():ObjectPool
		{
			return _socketPool;
		}
		
		/** 서버가 시작된 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다.(ms)
		 * 서버가 실행 중이 아닌 경우엔 -1을 반환한다.
		 */
		public function get elapsedTimeAfterRun():Number
		{
			if(_run == false)
			{
				return -1;
			}
			
			return getTimer() - _runnedTime;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(ms) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * (정보가 들어온 경우 자동으로 이 함수가 실행되어 갱신된다.)
		 */
		private function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer();
			dispatchEvent(_event);
		}
		
		/** address로 소켓을 가져온다. */
		public function getSocketByAddress(address:String):GogduNetSocket
		{
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.address == address)
				{
					return socket;
				}
			}
			
			return null;
		}
		
		/** 포트로 소켓을 가져온다. */
		public function getSocketByPort(port:int):GogduNetSocket
		{
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.port == port)
				{
					return socket;
				}
			}
			
			return null;
		}
		
		/** address와 포트가 모두 일치하는 소켓을 가져온다. */
		public function getSocketByAddressAndPort(address:String, port:int):GogduNetSocket
		{
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.address == address && socket.port == port)
				{
					return socket;
				}
			}
			
			return null;
		}
		
		/** id로 소켓을 가져온다. */
		public function getSocketByID(id:String):GogduNetSocket
		{
			if(_idTable[id] && _idTable[id] is GogduNetSocket)
			{
				return _idTable[id];
			}
			else
			{
				return null;
			}
			
			return null;
		}
		
		/** level로 소켓을 가져온다. */
		/*public function getSocketByLevel(level:int):GogduNetSocket
		{
		var i:uint;
		var socket:GogduNetSocket;
		
		for(i = 0; i < _socketArray.length; i += 1)
		{
		if(_socketArray[i] == null)
		{
		continue;
		}
		socket =_socketArray[i];
		if(socket.isConnected == false)
		{
		continue;
		}
		
		if(socket.level == level)
		{
		return socket;
		}
		}
		
		return null;
		}*/
		
		/** 모든 소켓을 가져온다. 반환되는 배열은 복사된 값이므로 수정하더라도 내부에 있는 원본 배열은 바뀌지 않는다. */
		public function getSockets(resultVector:Vector.<GogduNetSocket>=null):Vector.<GogduNetSocket>
		{
			if(resultVector == null)
			{
				resultVector = new Vector.<GogduNetSocket>();
			}
			
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket = _socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				resultVector.push(socket);
			}
			
			return resultVector;
		}
		
		/** address로 소켓들을 가져온다. */
		public function getSocketsByAddress(address:String, resultVector:Vector.<GogduNetSocket>=null):Vector.<GogduNetSocket>
		{
			if(resultVector == null)
			{
				resultVector = new Vector.<GogduNetSocket>();
			}
			
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.address == address)
				{
					resultVector.push(socket);
				}
			}
			
			return resultVector;
		}
		
		/** 포트로 소켓들을 가져온다. */
		public function getSocketsByPort(port:int, resultVector:Vector.<GogduNetSocket>=null):Vector.<GogduNetSocket>
		{
			if(resultVector == null)
			{
				resultVector = new Vector.<GogduNetSocket>();
			}
			
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.port == port)
				{
					resultVector.push(socket);
				}
			}
			
			return resultVector;
		}
		
		/** address와 포트가 모두 일치하는 소켓들을 가져온다. */
		public function getSocketsByAddressAndPort(address:String, port:int, resultVector:Vector.<GogduNetSocket>=null):Vector.<GogduNetSocket>
		{
			if(resultVector == null)
			{
				resultVector = new Vector.<GogduNetSocket>();
			}
			
			var i:uint;
			var socket:GogduNetSocket;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket =_socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(socket.address == address && socket.port == port)
				{
					resultVector.push(socket);
				}
			}
			
			return resultVector;
		}
		
		/** level로 소켓들을 가져온다. */
		/*public function getSocketsByLevel(level:int, resultVector:Vector.<GogduNetSocket>=null):Vector.<GogduNetSocket>
		{
		if(resultVector == null)
		{
		resultVector = new Vector.<GogduNetSocket>();
		}
		
		var i:uint;
		var socket:GogduNetSocket;
		
		for(i = 0; i < _socketArray.length; i += 1)
		{
		if(_socketArray[i] == null)
		{
		continue;
		}
		socket =_socketArray[i];
		if(socket.isConnected == false)
		{
		continue;
		}
		
		if(socket.level == level)
		{
		resultVector.push(socket);
		}
		}
		
		return resultVector;
		}*/
		
		// public function
		public function dispose():void
		{
			var socket:GogduNetSocket;
			
			while(_socketArray.length > 0)
			{
				socket = _socketArray.pop();
				
				if(socket == null)
				{
					continue;
				}
				
				socket.removeEventListener(Event.CLOSE, _socketClosed);
				continue;
			}
			
			_serverSocket.close();
			_serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.removeEventListener(Event.CLOSE, _closedByOS);
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			_timer = null;
			_serverSocket = null;
			_serverAddress = null;
			_encoding = null;
			_record.dispose();
			_record = null;
			_socketArray = null;
			_idTable = null;
			_event = null;
			_randomID.dispose();
			_randomID = null;
			_socketPool.dispose();
			_socketPool = null;
			_connectionSecurity.dispose();
			_connectionSecurity = null;
			
			_run = false;
		}
		
		/** 서버 작동 시작 */
		public function run():void
		{
			if(!_serverAddress || _run == true)
			{
				return;
			}
			
			_runnedTime = getTimer();
			_serverSocket.bind(_serverPort, _serverAddress);
			_serverSocket.listen();
			_serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.addEventListener(Event.CLOSE, _closedByOS);
			//addEventListener(Event.ENTER_FRAME, _timerFunc);
			_timer.start();
			_timer.addEventListener(TimerEvent.TIMER, _timerFunc);
			
			_run = true;
			_record.addRecord("Opened server(runnedTime:" + _runnedTime + ")", true);
		}
		
		/** 운영체제에 의해 소켓이 닫힘 */
		private function _closedByOS():void
		{
			_record.addRecord("Closed server by OS(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")", true);
			_close();
			dispatchEvent(new Event(Event.CLOSE));
		}
		
		/** 서버 작동 중지 */
		public function close():void
		{
			if(_run == false)
			{
				return;
			}
			
			_record.addRecord("Closed server(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")", true);
			_close();
		}
		
		private function _close():void
		{
			var socket:GogduNetSocket;
			
			while(_socketArray.length > 0)
			{
				socket =_socketArray.pop();
				
				if(socket == null)
				{
					continue;
				}
				socket.removeEventListener(Event.CLOSE, _socketClosed);
				_idTable[socket.id] = null;
				socket.nativeSocket.close();
				socket.dispose();
			}
			
			_socketArray.length = 0;
			_idTable = {};
			_randomID.clear();
			_socketPool.clear();
			
			_serverSocket.close();
			_serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.removeEventListener(Event.CLOSE, _close);
			_serverSocket = new ServerSocket(); //ServerSocket is non reusable after ServerSocket.close()
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			
			_run = false;
		}
		
		/** 2진 데이터를 전송한다. 함수 내부에서 자동으로 데이터에 헤더를 붙이지만, 이벤트로 데이터를 넘길 때 헤더가 자동으로 제거되므로
		 * 신경 쓸 필요는 없다. 그리고 definition(프로토콜 문자열)은 암호화되어 전송되고, 받았을 때 복호화되어 이벤트로 넘겨진다. 이
		 * 역시 클래스 내부에서 자동으로 처리되므로 신경 쓸 필요는 없다.(Encryptor 클래스를 수정하여 암호화 부분 수정 가능)<br/>
		 * ( 한 번에 전송할 수 있는 data의 최대 길이는 uint로 표현할 수 있는 최대값인 4294967295(=4GB)이며,
		 * definition 문자열의 최대 길이도 uint로 표현할 수 있는 최대값인 4294967295이다. )</br>
		 * (data 인자에 null을 넣으면, data는 길이가 0으로 전송된다.
		 */
		public function sendBytesToNativeSocket(nativeSocket:Socket, definition:String, data:ByteArray=null):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			//패킷 생성
			var packet:ByteArray = new ByteArray();
			//(프로토콜 문자열은 암호화되어 전송된다.)
			var defBytes:ByteArray = new ByteArray();
			defBytes.writeMultiByte( Encryptor.encode(definition), _encoding );
			
			//data가 존재할 경우
			if(data)
			{
				//헤더 생성
				packet.writeUnsignedInt( data.length ); //data size
				packet.writeUnsignedInt( defBytes.length ); //protocol length
				packet.writeBytes(defBytes, 0, defBytes.length); //protocol
				packet.writeBytes(data, 0, data.length); //data
			}
			
			//data가 null일 경우
			if(!data)
			{
				//헤더 생성
				packet.writeUnsignedInt( 0 ); //data size
				packet.writeUnsignedInt( defBytes.length ); //protocol length
				packet.writeBytes(defBytes, 0, defBytes.length); //protocol
			}
			
			nativeSocket.writeBytes( packet, 0, packet.length );
			nativeSocket.flush();
			return true;
		}
		
		public function sendBytes(socket:GogduNetSocket, definition:String, data:ByteArray=null):Boolean
		{
			return sendBytesToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendBytesToAll(definition:String, data:ByteArray=null):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var i:uint;
			var socket:GogduNetSocket;
			var tf:Boolean = true;
			
			for(i = 0; i < _socketArray.length; i += 1)
			{
				if(_socketArray[i] == null)
				{
					continue;
				}
				socket = _socketArray[i];
				if(socket.isConnected == false)
				{
					continue;
				}
				
				if(sendBytes(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		/** socket과의 연결을 끊는다.
		 */
		public function closeSocket(socket:GogduNetSocket):void
		{
			socket.removeEventListener(Event.CLOSE, _socketClosed);
			_idTable[socket.id] = null;
			
			socket.nativeSocket.close();
			socket.dispose();
			_socketPool.returnInstance(socket);
			_removeSocket(socket);
		}
		
		// private function
		/** _socketArray에서 socket을 제거한다. 성공적으로 제거한 경우엔 true를,
		 * _socketArray에 socket이 없어서 제거하지 못한 경우엔 false를 반환한다.
		 */
		private function _removeSocket(socket:GogduNetSocket):void
		{
			var idx:int = _socketArray.indexOf(socket);
			
			// _socketArray에 이 소켓이 존재할 경우
			if(idx != -1)
			{
				// _socketArray에서 이 소켓을 제거한다.
				_socketArray.splice(idx, 1);
			}
		}
		
		private function _forcedCloseNativeSocket(nativeSocket:Socket):void
		{
			try
			{
				nativeSocket.close();
			}
			catch(e:Error)
			{
				_record.addErrorRecord(e, "It occurred from forced closes nativeSocket connection", true);
			}
		}
		
		/** 클라이언트 접속 */
		private function _socketConnect(e:ServerSocketConnectEvent):void
		{
			var socket:Socket = e.socket;
			var bool:Boolean = false;
			
			if(_connectionSecurity.isPermission == true)
			{
				if(_connectionSecurity.contain(socket.remoteAddress, socket.remotePort) == true)
				{
					bool = true;
				}
			}
			else if(_connectionSecurity.isPermission == false)
			{
				if(_connectionSecurity.contain(socket.remoteAddress, socket.remotePort) == false)
				{
					bool = true;
				}
			}
			
			if(bool == false)
			{
				_record.addRecord("Sensed unpermitted connection(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(address:" + socket.remoteAddress + 
					", port:" + socket.remotePort + ")", true);
				dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.UNPERMITTED_CONNECTION, false, false, null, socket, null));
				socket.close();
				return;
			}
			
			// 잘못된 address로 접속 실패 (필요 없을 수도 있는 기능. 제작자도 이 오류 방지 if문이 필요한지 어떤지 잘 모름.)
			/*if(socket.remoteAddress == null)
			{
			_record.addRecord("What socket is failed connect(InvalidAddress)", true);
			socket.writeMultiByte(makePacket(DataType.DEFINITION, "GogduNet.Connect.Fail.InvalidAddress"), _encoding);
			socket.flush();
			setTimeout(_forcedCloseNativeSocket, 100, socket);
			
			dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CONNECT_FAILED, false, false, null, socket, GogduNetSocketEvent.INFO_INVALID_Address));
			return;
			}*/
			
			// 사용자 포화로 접속 실패
			if(currentSockets >= _maxSockets)
			{
				_record.addRecord("What socket is failed connect(Saturation)(address:" + socket.remoteAddress + ", port:" + socket.remotePort + ")", true);
				sendBytesToNativeSocket(socket, "GogduNet.Connect.Fail.Saturation", null);
				setTimeout(_forcedCloseNativeSocket, 100, socket);
				
				dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CONNECT_FAILED, false, false, null, socket, GogduNetSocketEvent.INFO_SATURATION));
				return;
			}
			
			// 접속 성공
			var socket2:GogduNetSocket = _socketPool.getInstance() as GogduNetSocket;
			socket2.initialize();
			socket2.setNativeSocket(socket);
			socket2.setID(_randomID.getID());
			//socket2.level = 1;
			
			_idTable[socket2.id] = socket2;
			socket2.addEventListener(Event.CLOSE, _socketClosed);
			socket2.updateLastReceivedTime();
			_socketArray.push(socket2);
			
			sendBytesToNativeSocket(socket, "GogduNet.Connect.Success", null); // socket == socket2.nativeSocket
			
			_record.addRecord("Client connected(id:" + socket2.id + ", address:" + socket.remoteAddress + ", port:" + socket.remotePort + ")", true);
			
			dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CONNECT, false, false, socket2, socket, null));
		}
		
		private function _socketClosed(e:Event):void
		{
			var socket:GogduNetSocket = e.currentTarget as GogduNetSocket;
			
			socket.removeEventListener(Event.CLOSE, _socketClosed);
			
			_record.addRecord("Connection to client is disconnected(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")", true);
			_removeSocket(socket);
			
			dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CLOSE, false, false, socket, socket.nativeSocket, GogduNetSocketEvent.INFO_NORMAL_CLOSE));
			
			_idTable[socket.id] = null;
			socket.nativeSocket.close();
			socket.dispose();
			_socketPool.returnInstance(socket);
		}
		
		/** 타이머로 반복되는 함수 */
		private function _timerFunc(e:TimerEvent):void
		{
			_listen();
		}
		
		/** 클라이언트의 접속을 검사. 문제가 있어 연결을 끊은 경우 true, 그렇지 않으면 false를 반환한다. */
		private function _checkConnect(socket:GogduNetSocket):Boolean
		{
			if(socket.isConnected == false)
			{
				socket.removeEventListener(Event.CLOSE, _socketClosed);
				_removeSocket(socket);
				_idTable[socket.id] = null;
				socket.nativeSocket.close();
				socket.dispose();
				_socketPool.returnInstance(socket);
				return true;
			}
			
			// 일정 시간 이상 전송이 오지 않을 경우 접속이 끊긴 것으로 간주하여 이쪽에서도 접속을 끊는다.
			if(socket.elapsedTimeAfterLastReceived > _connectionDelayLimit)
			{
				_record.addRecord("Disconnects connection to client(NoResponding)(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")", true);
				sendBytes(socket, "GogduNet.Disconnect.NoResponding", null);
				closeSocket(socket);
				dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CLOSE, false, false, socket, socket.nativeSocket, GogduNetSocketEvent.INFO_ABNORMAL_CLOSE));
				return true;
			}
			
			return false;
		}
		
		/** 정보 수신 */
		private function _listen():void
		{
			var socket:GogduNetSocket;
			var socketInSocket:Socket;
			var packetBytes:ByteArray; // 패킷을 읽을 때 쓰는 바이트 배열.
			var bytes:ByteArray; // 패킷을 읽을 때 보조용으로 쓰는 바이트 배열.
			
			var size:uint; //헤더에서 뽑아낸 파일의 최종 크기
			var protocolLength:uint; //헤더에서 뽑아낸 프로토콜 문자열의 길이
			var protocol:String; //프로토콜 문자열
			var data:ByteArray; //최종 데이터
			
			var i:uint;
			
			for each(socket in _socketArray)
			{
				if(socket == null)
				{
					continue;
				}
				
				if(_checkConnect(socket) == true)
				{
					continue;
				}
				
				socketInSocket = socket.nativeSocket;
				
				if(socketInSocket.bytesAvailable <= 0)
				{
					continue;
				}
				
				
				// 서버의 마지막 연결 시각을 갱신.
				updateLastReceivedTime();
				// 해당 소켓과의 마지막 연결 시각을 갱신.
				socket.updateLastReceivedTime();
				
				packetBytes = new ByteArray();
				bytes = socket._backupBytes;
				bytes.position = 0;
				packetBytes.position = 0;
				packetBytes.writeBytes(bytes, 0, bytes.length);
				//만약 AS가 아닌 C# 등과 통신할 경우 엔디안이 다르므로 오류가 날 수 있다. 그걸 방지하기 위함.
				socketInSocket.endian = Endian.LITTLE_ENDIAN;
				socketInSocket.readBytes(packetBytes, packetBytes.length, socketInSocket.bytesAvailable);
				bytes.length = 0; //bytes == socket._backupBytes
				
				//헤더가 다 전송되지 않은 경우
				if(packetBytes.length < 8)
				{
					packetBytes.position = 0;
					dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.PROGRESS_DATA, false, false, 
						socket, socketInSocket, DataType.BYTES, null, packetBytes) );
				}
				//패킷 바이트의 길이가 8 이상일 경우(즉, 크기 헤더와 프로토콜 문자열 길이 헤더가 있는 경우), 반복
				while(packetBytes.length >= 8)
				{
					try
					{
						packetBytes.position = 0;
						
						//헤더(크기 헤더)를 읽는다.
						size = packetBytes.readUnsignedInt(); //Unsigned Int : 4 byte
						
						//헤더(프로토콜 문자열 길이 헤더)를 읽는다.
						protocolLength = packetBytes.readUnsignedInt();
					}
					catch(e:Error)
					{
						//오류가 난 정보를 바이트 배열에서 제거
						bytes = new ByteArray();
						bytes.length = 0;
						bytes.position = 0;
						bytes.writeBytes(packetBytes, 0, packetBytes.length);
						packetBytes.length = 0;
						packetBytes.position = 0;
						//(length 인자를 0으로 주면, offset부터 읽을 수 있는 전부를 선택한다.)
						packetBytes.writeBytes(bytes, 8, 0);
						
						_record.addErrorRecord(e, "It occurred from read to data's header", true);
						break;
					}
					
					//프로토콜 문자열 길이 이상만큼 전송 된 경우
					//(bytesAvailable == length - position)
					if(packetBytes.bytesAvailable >= protocolLength)
					{
						try
						{
							//프로토콜 문자열을 담고 있는 바이트 배열을 문자열로 변환
							protocol = packetBytes.readMultiByte(protocolLength, _encoding);
							//변환된 문자열을 본래 프로토콜(전송되는 프로토콜은 암호화되어 있다)로 바꾸기 위해 복호화
							protocol = Encryptor.decode(protocol);
						}
						catch(e:Error)
						{
							//오류가 난 정보를 바이트 배열에서 제거
							bytes = new ByteArray();
							bytes.length = 0;
							bytes.position = 0;
							bytes.writeBytes(packetBytes, 0, protocolLength);
							packetBytes.length = 0;
							packetBytes.position = 0;
							//(length 인자를 0으로 주면, offset부터 읽을 수 있는 전부를 선택한다.)
							packetBytes.writeBytes(bytes, protocolLength, 0);
							
							_record.addErrorRecord(e, "It occurred from protocol bytes convert to string and decode protocol string", true);
							break;
						}
						
						//원래 사이즈만큼 완전히 전송이 된 경우
						//(bytesAvailable == length - position)
						if(packetBytes.bytesAvailable >= size)
						{
							data = new ByteArray();
							data.writeBytes( packetBytes, packetBytes.position, size );
							data.position = 0;
							
							_record.addRecord("Data received(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(id:" + 
								socket.id + ", address:" + socket.address + ", port:" + socket.port + ")", true);
							
							dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, 
								socket, socketInSocket, DataType.BYTES, protocol, data) );
							
							//사용한 정보를 바이트 배열에서 제거한다.
							bytes = new ByteArray();
							bytes.writeBytes(packetBytes, 0, packetBytes.length);
							packetBytes.clear();
							//(length 인자를 0으로 주면, offset부터 읽을 수 있는 전부를 선택한다.)
							packetBytes.writeBytes(bytes, 8 + protocolLength + size, 0);
						}
						//데이터가 아직 다 전송이 안 된 경우
						else
						{
							data = new ByteArray();
							data.writeBytes( packetBytes, packetBytes.position, packetBytes.bytesAvailable );
							data.position = 0;
							
							dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.PROGRESS_DATA, false, false, 
								socket, socketInSocket, DataType.BYTES, protocol, data) );
						}
					}
					//프로토콜 정보가 다 전송되지 않은 경우
					else
					{
						packetBytes.position = 0;
						dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.PROGRESS_DATA, false, false, 
							socket, socketInSocket, DataType.BYTES, null, packetBytes) );
					}
				}
				
				_backup(socket._backupBytes, packetBytes);
			}
		}
		
		/** 다 처리하고 난 후에도 남아 있는(패킷이 다 오지 않아 처리가 안 된) 데이터를 소켓의 _backupBytes에 임시로 저장해 둔다. */
		private function _backup(backupBytes:ByteArray, bytes:ByteArray):void
		{
			if(bytes.length > 0)
			{
				backupBytes.clear();
				backupBytes.writeBytes(bytes, 0, bytes.length);
			}
		}
	} // class
} // package