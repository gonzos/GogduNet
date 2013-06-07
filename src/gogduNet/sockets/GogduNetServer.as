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
	
	import gogduNet.events.GogduNetDataEvent;
	import gogduNet.events.GogduNetSocketEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.sockets.GogduNetSocket;
	import gogduNet.utils.Encryptor;
	import gogduNet.utils.RecordConsole;
	import gogduNet.utils.makePacket;
	import gogduNet.utils.parsePacket;
	import gogduNet.utils.ObjectPool;
	import gogduNet.utils.RandomID;
	
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
	/** 정상적인 데이터를 수신했을 때 발생. 데이터는 가공되어 이벤트로 전달된다. */
	[Event(name="receiveData", type="gogduNet.events.GogduNetDataEvent")]
	/** 정상적이지 않은 데이터를 수신했을 때 발생 */
	[Event(name="invalidPacket", type="gogduNet.events.GogduNetDataEvent")]
	
	/** <p>GogduNet는 간단하게 TCP 통신(GogduNetServer, GogduNetClient, GogduNetPolicyServer)이나 P2P UDP 통신(GogduNetP2PClient), UDP 통신(GogduNetUDPClient)을 구현해 주는 라이브러리입니다. 기본적으로 JSON 문자열로 통신을 합니다.</p>
	 * 
	 * <strong>GogduNet의 통신 규칙</strong>
	 * 
	 * <p>GogduNet이 통신을 할 때 지켜야 하는 규칙을 설명합니다. GogduNet 라이브러리를 그대로 사용할 거라면 몰라도 되지만,
	 * 만약 입맛대로 조금 수정하여 사용할 거라면 아는 게 좋습니다.</p>
	 * 
	 * <p>한 패킷은 <code>{"t":"내용", "df":"내용", "dt":"내용"}</code> 이런 형태로 구성됩니다. 여기서 t(type) 부분은 패킷 데이터의 형태(string, 
	 * array, int, uint 등)를 나타내며, df(definition) 부분은 데이터가 무얼 위해 보내졌는지(프로토콜)를 나타냅니다.(예로 "GogduNet.Message")
	 * 그리고 마지막으로 dt(data)는 실제 정보를 가지고 있는 부분이며, t(type)가 "def"인 경우에는 이 dt(data) 부분이 존재하지 않습니다.
	 * (예:{"t":"def", "df":"Check"})</br>
	 * 
	 * <strong></br>Data Type의 종류</strong>
	 * <p>(gogduNet.sockets.DataType에 상수로 정의되어 있습니다.)</p>
	 * 	<ul>
	 * 		<li>def:Definition (String) (ex. GogduNet.Connect.Success) (특이점으로, data 영역이 존재하지 않는다.)</li>
	 * 		<li>str:String (문자열)</li>
	 * 		<li>arr:Array (배열)</li>
	 * 		<li>int:Integer (정수)</li>
	 * 		<li>uint:Unsigned Integer (0 이상인 정수)</li>
	 * 		<li>rati:Rationals (유리수)</li>
	 * 		<li>tf:Boolean (true와 false)</li>
	 * 		<li>json:JSON (JSON 문자열. 수신한 뒤 Object 객체로 가공된다.)</li>
	 * 	</ul>
	 * 
	 * <strong></br>Tip</strong>
	 * 
	 * 	<ul>
	 * 		<li>패킷에서 def 영역은 String 값으로서, 그냥 "000"이나 "001" 같은 값을 사용해도 아무 상관이 없습니다.</li>
	 * 		<li>gogduNet.utils.Encryptor 클래스를 수정하여 암호화하는 방법을 바꿀 수 있습니다.(단, Base64 encode/decode 부분은 건들지 마세요.)</li>
	 * 		<li>GogduNetServer, GogduNetP2PClient, GogduNetUDPClient는 내부적으로 Object Pool를 사용합니다.</li>
	 * 	</ul>
	 * 
	 * <strong></br>기본적인 사용법(GogduNetServer, GogduNetClient)</strong>
	 * 
	 * <p>서버측</p>
	 * 
	 * 	<ol>
	 * 		<li>루프백 아이피(127.0.0.1), 1234 포트, 10명 제한으로 설정한 새 인스턴스를 생성한 뒤 서버를 시작한다.
	 * 			<p><code>var server:GogduNetServer = new GogduNetServer("127.0.0.1", 1234, 10);</br>server.run();</code></p></li>
	 * 		<li>클라이언트가 접속할 경우에 실행되는 이벤트로 추가할 함수를 만든다.(클라이언트가 접속할 경우 "愛してる, ミクちゃん!"라는 메세지를 보내는 함수이다.)
	 * 			<p><code>function socketConnect(e:GogduNetSocketEvent):void</br>
	 * 			{</br>
	 * 			　trace("connect");</br>
	 * 			　server.sendString(e.socket, "GogduNet.Test.Message", "愛してる, ミクちゃん!");</br>
	 * 			　trace("sended");</br>
	 * 			}</code></p></li>
	 * 		<li>위에서 만든 함수를 클라이언트가 접속할 경우에 실행되는 이벤트로 추가한다.
	 * 			<p><code>server.addEventListener(GogduNetSocketEvent.CONNECT, socketConnect);</code></p></li>
	 * 	</ol>
	 * 
	 * <p>클라이언트측</p>
	 * 
	 * 	<ol>
	 * 		<li>새 인스턴스를 생성한 뒤 address:127.0.0.1, 포트:1234인 서버에 접속한다.
	 * 			<p><code>var client:GogduNetClient = new GogduNetClient("127.0.0.1", 1234);</br>
	 * 			client.connect();</code></p></li>
	 * 		<li>서버에서 데이터가 올 경우에 실행되는 이벤트로 추가할 함수를 만든다.
	 * 			<p><code>function dataGet(e:GogduNetDataEvent):void</br>
	 * 			{</br>
	 *			　if(e.dataType == DataType.STRING)</br>
	 * 			　{</br>
	 * 			　　if(e.dataDefinition == "GogduNet.Test.Message")</br>
	 * 			　　{</br>
	 * 			　　　trace(e.data);</br>
	 * 			　　}</br>
	 * 			　}</br>
	 * 			}</code></p></li>
	 * 		<li>위에서 만든 함수를 서버에서 데이터가 올 경우에 실행되는 이벤트로 추가한다.
	 * 			<p><code>client.addEventListener(GogduNetDataEvent.RECEIVE_DATA, dataGet);</code></p></li>
	 * 	</ol>
	 * 
	 * <p>이제 서버-클라이언트 순으로 실행하여 테스트해 보면, 클라이언트측에서 메시지를 받은 것을 확인할 수 있다.</p>
	 * 
	 * @langversion 3.0
	 * @playerversion GogduNetServer·GogduNetPolicyServer·GogduNetUDPClient : AIR 3.0 Desktop·AIR 3.8
	 * @playerversion GogduNetClient·GogduNetP2PClient : Flash Player 11·AIR 3.0
	 */
	public class GogduNetServer extends EventDispatcher
	{
		private var _timer:Timer;
		
		// 서버 설정
		/** 최대 연결 지연 한계 **/
		private var _connectionDelayLimit:Number;
		
		/** 패킷을 추출할 때 사용할 정규 표현식 */
		//private	var _reg:RegExp = /\{([^{}]|(?=\\){|(?=\\)})+\}/g
		//private	var _reg:RegExp = /\{\s*"type":(("(([^"]|(?<=\\)")*)"|([0-9]+)|null|false|true)+,{1}\s*)"def":(("(([^"]|(?<=\\)")*)"|([0-9]+)|null|false|true)+)(,{1}\s*"data":("(([^"]|(?<=\\)")*)"|([0-9]+)|null|false|true)+)*\s*\}/g;
		private	var _reg:RegExp = /(?!\.)[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]+\./g;
		/** 필요 없는 패킷들을 제거할 때 사용할 정규 표현식 */
		//private var _reg2:RegExp = /{([^ \t-~]|\w)+}|((?!{)[^{}]+(?={))|({+([^ \t-~]|\w)+)|((([^ \t-~]|\w)+}+)|{(?={)|(?<=})})|({})/g;
		private var _reg2:RegExp = /[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]*[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/\.=]+[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstupvxyz0123456789\+\/=]*|(?<=\.)\.+|(?<!.)\./g;
		
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
		private var _maxPersons:uint;
		/** 최대 동시 접속자 수 */
		private var _maxConcurrentConnectionPersons:uint;
		/** 접속자 누적 수 */
		private var _cumulativePersons:uint;
		/** 접속자 누적 수가 uint의 최대값을 넘어갔을 경우 이 변수를 1 더하고 접속자 누적 수를 초기화. */
		private var _garbageCumulativePeople:uint;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		/** 클라이언트 소켓 배열 */
		private var _socketArray:Vector.<GogduNetSocket>;
		/** 소켓 객체의 id를 주소값으로 사용하여 저장하는 객체 */
		private var _idTable:Object;
		
		private var _event:GogduNetSocketEvent;
		
		private var _randomID:RandomID;
		
		private var _socketPool:ObjectPool;
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체 */
		private var _connectionSecurity:GogduNetConnectionSecurity;
		
		/** <p>serverAddress : 서버로 사용할 address</p>
		 * <p>serverPort : 서버로 사용할 포트</p>
		 * <p>maxPersons : 최대 인원 수 제한</p>
		 * <p>timerInterval : 정보 수신과 연결 검사를 할 때 사용할 타이머의 반복 간격(밀리초 단위)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(여기서 설정한 시간 동안 소켓으로부터 데이터가 오지 않으면 그 소켓과는 연결이 끊긴 것으로 간주한다. 초 단위)</p>
		 * <p>encoding : 통신을 할 때 사용할 인코딩 형식</p>
		 */
		public function GogduNetServer(serverAddress:String="0.0.0.0", serverPort:int=0, maxPersons:uint=10, connectionSecurity:GogduNetConnectionSecurity=null, timerInterval:Number=20,
										connectionDelayLimit:Number=10, encoding:String="UTF-8")
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
			_maxPersons = maxPersons;
			_maxConcurrentConnectionPersons = 0;
			_cumulativePersons = 0;
			_garbageCumulativePeople = 0;
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
		
		/** 연결 지연 한계를 가져온다.(초 단위) */
		public function get connectionDelayLimit():Number
		{
			return _connectionDelayLimit;
		}
		/** 연결 지연 한계를 설정한다.(초 단위) */
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
		public function get maxPersons():uint
		{
			return _maxPersons;
		}
		public function set maxPersons(value:uint):void
		{
			_maxPersons =value;
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
		public function get currentPersons():uint
		{
			return _socketArray.length;
		}
		
		/** 서버의 최대 동접 수를 가져온다. */
		public function get maxConcurrentConnectionPersons():uint
		{
			return _maxConcurrentConnectionPersons;
		}
		
		/** 서버의 인원 누적 수를 가져온다. (서버를 시작한 후 연결에 성공했던 모든 수를 나타내며,
		 * close() 함수로 서버를 닫아도 그대로 남아있으나, run() 함수로 서버를 다시 시작하면 값이 초기화된다.)
		 */
		public function get cumulativePersons():uint
		{
			return _cumulativePersons;
		}
		
		/** 서버의 쓰레기 인원 누적 수(cumulativePersons의 값이 uint의 최대값을 넘어가려고 하는 경우, garbageCumulativePeople의 값이 1 오르고
		 * cumulativePersons의 값이 0으로 초기화된다.)를 가져온다.
		 * (close() 함수로 서버를 닫아도 그대로 남아있으나, run() 함수로 서버를 다시 시작하면 값이 초기화된다.)
		 */
		public function get garbageCumulativePeople():uint
		{
			return _garbageCumulativePeople;
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
		
		/** 서버가 시작된 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다. (초 단위)
		 * 서버가 실행 중이 아닌 경우엔 -1을 반환한다.
		 */
		public function get elapsedTimeAfterRun():Number
		{
			if(_run == false)
			{
				return -1;
			}
			
			return getTimer() / 1000.0 - _runnedTime;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(초 단위) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() / 1000.0 - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * (정보가 들어온 경우 자동으로 이 함수가 실행되어 갱신된다.)
		 */
		private function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer() / 1000.0;
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
				socket =_socketArray[i];
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
			_reg = null;
			_reg2 = null;
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
			
			_runnedTime = getTimer() / 1000.0;
			_serverSocket.bind(_serverPort, _serverAddress);
			_serverSocket.listen();
			_serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.addEventListener(Event.CLOSE, _closedByOS);
			//addEventListener(Event.ENTER_FRAME, _timerFunc);
			_timer.start();
			_timer.addEventListener(TimerEvent.TIMER, _timerFunc);
			
			_cumulativePersons = 0;
			_garbageCumulativePeople = 0;
			
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
		
		public function sendDefinitionToNativeSocket(nativeSocket:Socket, definition:String):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.DEFINITION, definition);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendStringToNativeSocket(nativeSocket:Socket, definition:String, data:String):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.STRING, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendArrayToNativeSocket(nativeSocket:Socket, definition:String, data:Array):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.ARRAY, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendIntegerToNativeSocket(nativeSocket:Socket, definition:String, data:int):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendUnsignedIntegerToNativeSocket(nativeSocket:Socket, definition:String, data:uint):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.UNSIGNED_INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendRationalsToNativeSocket(nativeSocket:Socket, definition:String, data:Number):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.RATIONALS, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendBooleanToNativeSocket(nativeSocket:Socket, definition:String, data:Boolean):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.BOOLEAN, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		/** this data's type is Object or String**/
		public function sendJSONToNativeSocket(nativeSocket:Socket, definition:String, data:Object):Boolean
		{
			if(_run == false)
			{
				return false;
			}
			
			if(data is String)
			{
				try
				{
					data = JSON.parse(String(data));
				}
				catch(e:Error)
				{
					return false;
				}
			}
			
			var str:String = makePacket(DataType.JSON, definition, data);
			if(str == null)
			{
				return false;
			}
			
			nativeSocket.writeMultiByte(str, _encoding);
			nativeSocket.flush();
			return true;
		}
		
		public function sendDefinition(socket:GogduNetSocket, definition:String):Boolean
		{
			return sendDefinitionToNativeSocket(socket.nativeSocket, definition);
		}
		
		public function sendString(socket:GogduNetSocket, definition:String, data:String):Boolean
		{
			return sendStringToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendArray(socket:GogduNetSocket, definition:String, data:Array):Boolean
		{
			return sendArrayToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendInteger(socket:GogduNetSocket, definition:String, data:int):Boolean
		{
			return sendIntegerToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendUnsignedInteger(socket:GogduNetSocket, definition:String, data:uint):Boolean
		{
			return sendUnsignedIntegerToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendRationals(socket:GogduNetSocket, definition:String, data:Number):Boolean
		{
			return sendRationalsToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		public function sendBoolean(socket:GogduNetSocket, definition:String, data:Boolean):Boolean
		{
			return sendBooleanToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		/** this data's type is Object or String**/
		public function sendJSON(socket:GogduNetSocket, definition:String, data:Object):Boolean
		{
			return sendJSONToNativeSocket(socket.nativeSocket, definition, data);
		}
		
		/** 하나의 소켓이라도 전송에 실패(패킷 형식에 맞지 않는 등의 이유로)한 경우 false를, 그렇지 않으면 true를 반환합니다. */
		public function sendDefinitionToAll(definition:String):Boolean
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
				
				if(sendDefinition(socket, definition) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendStringToAll(definition:String, data:String):Boolean
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
				
				if(sendString(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendArrayToAll(definition:String, data:Array):Boolean
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
				
				if(sendArray(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendIntegerToAll(definition:String, data:int):Boolean
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
				
				if(sendInteger(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendUnsignedIntegerToAll(definition:String, data:uint):Boolean
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
				
				if(sendUnsignedInteger(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendRationalsToAll(definition:String, data:Number):Boolean
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
				
				if(sendRationals(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendBooleanToAll(definition:String, data:Boolean):Boolean
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
				
				if(sendBoolean(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		/** this data's type is Object or String**/
		public function sendJSONToAll(definition:String, data:Object):Boolean
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
				
				if(sendJSON(socket, definition, data) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		/** nativeSocket과의 연결을 끊는다.
		 * 먼저 소켓에게 연결이 끊긴다는 definition을 보내고, 일정 시간 뒤에 강제로 연결을 끊는다.
		 */
		public function closeNativeSocket(nativeSocket:Socket):void
		{
			if(nativeSocket.connected == false)
			{
				return;
			}
			
			sendDefinitionToNativeSocket(nativeSocket, "GogduNet.Disconnect");
			setTimeout(_forcedCloseNativeSocket, 100, nativeSocket);
		}
		
		/** socket과의 연결을 끊는다.
		 * 먼저 소켓에게 연결이 끊긴다는 definition을 보내고, 일정 시간 뒤에 강제로 연결을 끊는다.
		 */
		public function closeSocket(socket:GogduNetSocket):void
		{
			socket.removeEventListener(Event.CLOSE, _socketClosed);
			var nativeSocket:Socket = socket.nativeSocket;
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
				_record.addErrorRecord(e, "It occurred from forced closes connection", true);
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
			if(currentPersons >= _maxPersons)
			{
				_record.addRecord("What socket is failed connect(Saturation)(address:" + socket.remoteAddress + ", port:" + socket.remotePort + ")", true);
				socket.writeMultiByte(makePacket(DataType.DEFINITION, "GogduNet.Connect.Fail.Saturation"), _encoding);
				socket.flush();
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
			
			sendDefinitionToNativeSocket(socket, "GogduNet.Connect.Success"); // socket == socket2.nativeSocket
			
			// 현재 접속자가 최대 동시 접속자보다 많을 경우, 동접 수를 갱신.
			if(currentPersons > _maxConcurrentConnectionPersons)
			{
				_maxConcurrentConnectionPersons = currentPersons;
			}
			
			// 누적 접속 수가 uint의 최대값을 넘으려고 할 경우, _garbageCumulativePeople를 1 더하고 _cumulativePersons을 0으로 설정한다.
			if(_cumulativePersons >= uint.MAX_VALUE)
			{
				_garbageCumulativePeople += 1;
				_cumulativePersons = 0;
			}
			
			_cumulativePersons += 1;
			
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
				sendDefinition(socket, "GogduNet.Disconnect.NoResponding");
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
			var bytes:ByteArray; // 패킷을 읽을 때 보조용으로 한 번만 쓰는 일회용 문자열.
			var regArray:Array; // 정규 표현식으로 찾은 문자열들을 저장해 두는 배열
			var jsonObj:Object // 문자열을 JSON으로 변환할 때 사용하는 객체
			var packetStr:String; // byte을 String으로 변환하여 읽을 때 쓰는 문자열.
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
				
				// packetBytes는 socket.packetBytes + socketInSocket의 값을 가지게 된다.
				try
				{
					packetBytes = new ByteArray();
					bytes = socket._backupBytes;
					bytes.position = 0;
					packetBytes.position = 0;
					packetBytes.writeBytes(bytes, 0, bytes.length);
					socketInSocket.readBytes(packetBytes, packetBytes.length, socketInSocket.bytesAvailable);
					bytes.length = 0; //bytes == socket._backupBytes
					
					//만약 AS가 아닌 C# 등과 통신할 경우 엔디안이 다르므로 오류가 날 수 있다. 그걸 방지하기 위함.
					packetBytes.endian = Endian.LITTLE_ENDIAN;
				}
				catch(e:Error)
				{
					_record.addErrorRecord(e, "It occurred from read to socket's packet", true);
					continue;
				}
				
				// 정보(byte)를 String으로 읽는다.
				try
				{
					packetBytes.position = 0;
					packetStr = packetBytes.readMultiByte(packetBytes.length, _encoding);
				}
				catch(e:Error)
				{
					_record.addErrorRecord(e, "It occurred from packet bytes convert to string", true);
					continue;
				}
				
				// 필요 없는 잉여 패킷(잘못 전달되었거나 악성 패킷)이 있으면 제거한다.
				if(_reg2.test(packetStr) == true)
				{
					_record.addRecord("Sensed surplus packets(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")(str:" + packetStr + ")", true);
					_record.addByteRecord(packetBytes, true);
					dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.INVALID_PACKET, false, false, socket, socketInSocket, null, null, packetBytes));
					packetStr.replace(_reg2, "");
				}
				
				//_reg:정규표현식 에 매치되는 패킷을 가져온다.
				regArray = packetStr.match(_reg);
				//가져온 패킷을 문자열에서 제거한다.
				packetStr = packetStr.replace(_reg, "");
				
				for(i = 0; i < regArray.length; i += 1)
				{
					if(!regArray[i])
					{
						continue;
					}
				
					// 패킷에 오류가 있는지를 검사합니다.
					jsonObj = parsePacket(regArray[i]);
					
					// 패킷에 오류가 있으면
					if(jsonObj == null)
					{
						_record.addRecord("Sensed wrong packets(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")(str:" + regArray[i] + ")", true);
						dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.INVALID_PACKET, false, false, socket, socketInSocket, null, null, packetBytes));
						continue;
					}
					// 패킷에 오류가 없으면
					else
					{
						if(jsonObj.t == DataType.DEFINITION)
						{
							_record.addRecord("Data received(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")"/*(type:" + jsonObj.type + ", def:" + 
								jsonObj.def + ")"*/, true);
							dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, socket, socketInSocket, jsonObj.t, jsonObj.df, null));
						}
						else
						{
							_record.addRecord("Data received(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")(id:" + socket.id + ", address:" + socket.address + ", port:" + socket.port + ")"/*(type:" + jsonObj.type + ", def:" + 
								jsonObj.def + ", data:" + jsonObj.data + ")"*/, true);
							dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, socket, socketInSocket, jsonObj.t, jsonObj.df, jsonObj.dt));
						}
					}
				}
				
				// 다 처리하고 난 후에도 남아 있는(패킷이 다 오지 않아 처리가 안 된) 정보(byte)를 소켓의 _backupBytes에 임시로 저장해 둔다.
				if(packetStr.length > 0)
				{
					bytes = socket._backupBytes;
					bytes.length = 0;
					bytes.position = 0;
					bytes.writeMultiByte(packetStr, _encoding);
				}
			}
		}
	} // class
} // package
