package gogduNet.sockets
{
	import flash.events.DatagramSocketDataEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.net.DatagramSocket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import gogduNet.utils.ObjectPool;
	
	import gogduNet.events.GogduNetConnectionEvent;
	import gogduNet.events.GogduNetUDPDataEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.utils.Encryptor;
	import gogduNet.utils.RecordConsole;
	import gogduNet.utils.makePacket;
	import gogduNet.utils.parsePacket;
	
	/** 운영체제 등에 의해 비자발적으로 연결이 끊긴 경우 발생 */
	[Event(name="close", type="flash.events.Event")]
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetConnectionEvent")]
	/** 허용되지 않은 대상에게서 정보가 전송되면 발생 */
	[Event(name="unpermittedConnection", type="gogduNet.events.GogduNetConnectionEvent")]
	/** 연결 지연 한계를 초과하여(응답 없음 상태라서) 저장된 데이터를 지운 경우 발생 */
	[Event(name="dataRemoved", type="gogduNet.events.GogduNetConnectionEvent")]
	/** 정상적인 데이터를 수신했을 때 발생. 데이터는 가공되어 이벤트로 전달된다. */
	[Event(name="receiveData", type="gogduNet.events.GogduNetUDPDataEvent")]
	/** 정상적이지 않은 데이터를 수신했을 때 발생 */
	[Event(name="invalidPacket", type="gogduNet.events.GogduNetUDPDataEvent")]
	
	public class GogduNetUDPClient extends EventDispatcher
	{
		private var _timer:Timer;
		
		// 설정
		/** 최대 연결 지연 한계 */
		private var _connectionDelayLimit:Number;
		/** 서버와 마지막으로 통신한 시각(정확히는 마지막으로 서버로부터 정보를 전송 받은 시각) */
		private var _lastReceivedTime:Number;
		
		/** 패킷을 추출할 때 사용할 정규 표현식 */
		private	var _reg:RegExp = /(?!\.)[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]+\./g;
		/** 필요 없는 패킷들을 제거할 때 사용할 정규 표현식 */
		private var _reg2:RegExp = /[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]*[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/\.=]+[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstupvxyz0123456789\+\/=]*|(?<=\.)\.+|(?<!.)\./g;
		
		/** 소켓 */
		private var _socket:DatagramSocket;
		
		/** 소켓이 바인딩된 로컬 address */
		private var _thisAddress:String;
		/** 소켓이 바인딩된 로컬 포트 */
		private var _thisPort:int;
		
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체 */
		private var _connectionSecurity:GogduNetConnectionSecurity;
		
		/** 서버 인코딩 유형(기본값="UTF-8") */
		private var _encoding:String;
		
		// 상태
		/** 현재 연결되어 있는가를 나타내는 bool 값 */
		private var _isReceiving:Boolean;
		/** 연결된 지점의 시간을 나타내는 변수 */
		private var _receivedTime:Number;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		private var _event:GogduNetConnectionEvent;
		
		private var _connectionTable:Object;
		private var _connectionPool:ObjectPool;
		
		/** <p>thisAddress : 바인드할 로컬 address (주로 자신의 address)</p>
		 * <p>thisPort : 바인드할 로컬 포트 (주로 자신의 포트)</p>
		 * <p>connectionSecurity : 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체. 값이 null인 경우 자동으로 생성(new GogduNetConnectionSecurity(false))</p>
		 * <p>timerInterval : 정보 수신과 연결 검사를 할 때 사용할 타이머의 반복 간격(밀리초 단위)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(여기서 설정한 시간 동안 서버로부터 데이터가 오지 않으면 서버와 연결이 끊긴 것으로 간주한다. 초 단위) (설명에선 편의상 연결이란 단어를 썼지만, 정확한 의미는 조금 다르다. UDP 통신은 상대가 수신 가능한지를 따지지 않고 그냥 데이터를 보내기만 한다. 설명에서 연결이 끊긴 것으로 간주한다는 말은, 그 대상으로부터 받아 저장해 두고 있던 정보를 없애겠다는 뜻이다.)</p>
		 * <p>encoding : 통신을 할 때 사용할 인코딩 형식</p>
		 */
		public function GogduNetUDPClient(thisAddress:String="0.0.0.0", thisPort:int=0, connectionSecurity:GogduNetConnectionSecurity=null, 
										  timerInterval:Number=20, connectionDelayLimit:Number=10, 
										  encoding:String="UTF-8")
		{
			_timer = new Timer(timerInterval);
			
			_connectionDelayLimit = connectionDelayLimit;
			_lastReceivedTime = -1;
			
			_socket = new DatagramSocket();
			
			_thisAddress = thisAddress;
			_thisPort = thisPort;
			
			if(connectionSecurity == null)
			{
				connectionSecurity = new GogduNetConnectionSecurity(false);
			}
			_connectionSecurity = connectionSecurity;
			
			_encoding = encoding;
			
			_receivedTime = -1;
			
			_record = new RecordConsole();
			_event = new GogduNetConnectionEvent(GogduNetConnectionEvent.CONNECTION_UPDATED, false, false, null);
			
			_connectionTable = new Object();
			_connectionPool = new ObjectPool(GogduNetConnection);
		}
		
		/** 실행용 타이머의 재생 간격을 가져온다. */
		public function get timerInterval():Number
		{
			return _timer.delay;
		}
		/** 실행용 타이머의 재생 간격을 설정한다. */
		public function set timerInterval(value:Number):void
		{
			_timer.delay = value;
		}
		
		/** 연결 지연 한계를 가져온다. */
		public function get connectionDelayLimit():Number
		{
			return _connectionDelayLimit;
		}
		/** 연결 지연 한계를 설정한다. */
		public function set connectionDelayLimit(value:Number):void
		{
			_connectionDelayLimit = value;
		}
		
		// setter, getter
		/** 소켓을 가져온다. */
		public function get socket():DatagramSocket
		{
			return _socket;
		}
		
		/** 소켓이 바인딩된 로컬 address를 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get thisAddress():String
		{
			return _thisAddress;
		}
		public function set thisAddress(value:String):void
		{
			if(_isReceiving == true)
			{
				return;
			}
			
			_thisAddress = value;
		}
		
		/** 소켓이 바인딩된 로컬 포트를 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get thisPort():int
		{
			return _thisPort;
		}
		public function set thisPort(value:int):void
		{
			if(_isReceiving == true)
			{
				return;
			}
			
			_thisPort = value;
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
		
		/** 통신 인코딩 유형을 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get encoding():String
		{
			return _encoding;
		}
		public function set encoding(value:String):void
		{
			if(_isReceiving == true)
			{
				return;
			}
			
			_encoding = value;
		}
		
		/** 현재 패킷 수신을 허용하고 있는가를 나타내는 값을 가져온다. */
		public function get isReceiving():Boolean
		{
			return _isReceiving;
		}
		
		/** 디버그용 기록을 가져온다. */
		public function get record():RecordConsole
		{
			return _record;
		}
		
		/** GogduNetConnection용 Object Pool이다. GogduNetUDPClient.close() 함수로 데이터 수신을 그만둘 경우, 
		 * ObjectPool.clear() 함수로 초기화된다. */
		public function get connectionPool():ObjectPool
		{
			return _connectionPool;
		}
		
		/** 수신을 시작한 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다. */
		public function get elapsedTimeAfterReceived():Number
		{
			if(_isReceiving == false)
			{
				return -1;
			}
			
			return getTimer() / 1000.0 - _receivedTime;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다. */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() / 1000.0 - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * (서버에게서 정보가 들어온 경우 자동으로 이 함수가 실행되어 갱신된다.)
		 */
		public function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer() / 1000.0;
			dispatchEvent(_event);
		}
		
		// public function
		public function dispose():void
		{
			_socket.close();
			_socket.removeEventListener(Event.CLOSE, _closedByOS);
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			_timer = null;
			_reg = null;
			_reg2 = null;
			_socket = null;
			_connectionSecurity.dispose();
			_connectionSecurity = null;
			_encoding = null;
			_record.dispose();
			_record = null;
			_event = null;
			_connectionTable = null;
			_connectionPool.dispose();
			_connectionPool = null;
			
			_isReceiving = false;
		}
		
		/** 바인딩된 Address 주소 및 포트에서 들어오는 패킷을 수신할 수 있도록 합니다.
		 * (GogduNetUDPClient 클래스는 별도의 connect() 함수가 없습니다. 특정한 대상의 데이터만 수신하고 싶다면 
		 * permittedConnections 속성을 설정하세요.)
		 */
		public function receive():void
		{
			if(!_thisAddress || _isReceiving == true)
			{
				return;
			}
			
			_socket.bind(_thisPort, _thisAddress);
			_socket.receive();
			
			_receivedTime = getTimer() / 1000.0;
			updateLastReceivedTime();
			_record.addRecord("Started receiving(receivedTime:" + _receivedTime + ")", true);
			
			_socket.addEventListener(Event.CLOSE, _closedByOS);
			_socket.addEventListener(DatagramSocketDataEvent.DATA, _getData);
			_timer.start();
			_timer.addEventListener(TimerEvent.TIMER, _timerFunc);
			
			_isReceiving = true;
		}
		
		/** 서버와의 연결을 끊음 */
		public function close():void
		{
			if(_isReceiving == false)
			{
				return;
			}
			
			_record.addRecord("Stopped receiving(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")", true);
			_close();
		}
		
		private function _close():void
		{
			_socket.close();
			_socket.removeEventListener(Event.CLOSE, _closedByOS);
			_socket.removeEventListener(DatagramSocketDataEvent.DATA, _getData);
			_socket = new DatagramSocket(); //DatagramSocket is non reusable after DatagramSocket.close()
			
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			
			_connectionTable = {};
			_connectionPool.clear();
			
			_isReceiving = false;
		}
		
		/** 운영체제에 의해 소켓이 닫힘 */
		private function _closedByOS():void
		{
			_record.addRecord("Stopped receiving by OS(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")", true);
			_close();
			dispatchEvent(new Event(Event.CLOSE));
		}
		
		/** 패킷 형식에 맞지 않는 등의 이유로 전송이 안 된 경우 false를, 그렇지 않으면 true를 반환합니다. */
		public function sendDefinition(definition:String, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.DEFINITION, definition);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendString(definition:String, data:String, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.STRING, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendArray(definition:String, data:Array, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.ARRAY, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendInteger(definition:String, data:int, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendUnsignedInteger(definition:String, data:uint, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.UNSIGNED_INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendRationals(definition:String, data:Number, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.RATIONALS, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		public function sendBoolean(definition:String, data:Boolean, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.BOOLEAN, definition, data);
			if(str == null)
			{
				return false;
			}
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		/** this data's type is Object or String**/
		public function sendJSON(definition:String, data:Object, address:String, port:int):Boolean
		{
			if(_isReceiving == false)
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
			
			var bytes:ByteArray = new ByteArray();
			bytes.writeMultiByte(str, _encoding);
			_socket.send(bytes, 0, bytes.length, address, port);
			return true;
		}
		
		/** 허용 또는 비허용되어 있는 모든 연결(GogduNetConnectionSecurity)에게 데이터를 전송합니다.
		 * GogduNetConnectionSecurity에 허용/비허용되어 있는 연결이 없을 경우 아무에게도 전송되지 않습니다.(하지만 반환값은 true입니다)
		 * 그리고 GogduNetConnectionSecurity.isPermission 속성이 false라도 전송됩니다.
		 */
		public function sendDefinitionToAll(definition:String):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendDefinition(definition, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendStringToAll(definition:String, data:String):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendString(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendArrayToAll(definition:String, data:Array):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendArray(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendIntegerToAll(definition:String, data:int):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendInteger(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendUnsignedIntegerToAll(definition:String, data:uint):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendUnsignedInteger(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendRationalsToAll(definition:String, data:Number):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendRationals(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendBooleanToAll(definition:String, data:Boolean):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendBoolean(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		public function sendJSONToAll(definition:String, data:Object):Boolean
		{
			if(_isReceiving == false)
			{
				return false;
			}
			
			var i:uint;
			var conn:Object;
			var tf:Boolean = true;
			var conns:Vector.<Object> = _connectionSecurity.connections;
			
			for(i = 0; i < conns.length; i += 1)
			{
				if(!conns[i])
				{
					continue;
				}
				conn = conns[i];
				
				if(sendJSON(definition, data, conn.address, conn.port) == false)
				{
					tf = false;
				}
			}
			
			return tf;
		}
		
		/** 정보 수신 */
		private function _getData(e:DatagramSocketDataEvent):void
		{
			updateLastReceivedTime();
			
			var connection:GogduNetConnection;
			var bool:Boolean = false;
			
			if(_connectionSecurity.isPermission == true)
			{
				if(_connectionSecurity.contain(e.srcAddress, e.srcPort) == true)
				{
					bool = true;
				}
			}
			else if(_connectionSecurity.isPermission == false)
			{
				if(_connectionSecurity.contain(e.srcAddress, e.srcPort) == false)
				{
					bool = true;
				}
			}
			
			if(bool == false)
			{
				connection = _connectionPool.getInstance() as GogduNetConnection;
				connection.initialize();
				connection.setAddress(e.srcAddress);
				connection.setPort(e.srcPort);
				connection.updateLastReceivedTime();
				
				_record.addRecord("Sensed unpermitted connection(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")(address:" + connection.address + 
					", port:" + connection.port + ")", true);
				dispatchEvent(new GogduNetConnectionEvent(GogduNetConnectionEvent.UNPERMITTED_CONNECTION, false, false, connection));
				
				connection.dispose();
				_connectionPool.returnInstance(connection);
				return;
			}
			
			//테이블에 정보가 존재하지 않을 경우 새로 생성
			if(!_connectionTable[e.srcAddress])
			{
				_connectionTable[e.srcAddress] = {};
			}
			if(!_connectionTable[e.srcAddress][e.srcPort])
			{
				_connectionTable[e.srcAddress][e.srcPort] = _connectionPool.getInstance() as GogduNetConnection;
				connection = _connectionTable[e.srcAddress][e.srcPort];
				connection.initialize();
				connection.setAddress(e.srcAddress);
				connection.setPort(e.srcPort);
			}
			
			connection = _connectionTable[e.srcAddress][e.srcPort];
			//수신한 데이터를 connection의 데이터 저장소에 쓴다.
			e.data.position = 0;
			connection._backupBytes.writeBytes(e.data, 0, e.data.length);
			//마지막 연결 시각을 갱신
			connection.updateLastReceivedTime();
		}
		
		private function _removeConnection(connection:GogduNetConnection):void
		{
			if(!_connectionTable[connection.address][connection.port])
			{
				return;
			}
			
			_connectionTable[connection.address][connection.port] = null;
			connection.dispose();
			connectionPool.returnInstance(connection);
			
			//만약 _connectionTable[connection.address]에 아무것도 존재하지 않을 경우 그것을 제거한다.
			var bool:Boolean = false;
			for each(var obj:Object in _connectionTable[connection.address])
			{
				bool = true;
				break;
			}
			if(bool == false)
			{
				_connectionTable[connection.address] = null;
			}
		}
		
		/** 클라이언트의 접속을 검사. 문제가 있어 데이터를 없앤 경우 true, 그렇지 않으면 false를 반환한다. */
		private function _checkConnect(connection:GogduNetConnection):Boolean
		{
			// 일정 시간 이상 전송이 오지 않을 경우, 관련 저장 정보를 모두 지운다.(연결 안 하는 것으로 간주)
			if(connection.elapsedTimeAfterLastReceived > _connectionDelayLimit)
			{
				_record.addRecord("Remove no responding connection's data(address:" + connection.address + ", port:" + connection.port + ")", true);
				_removeConnection(connection);
				dispatchEvent(new GogduNetConnectionEvent(GogduNetConnectionEvent.DATA_REMOVED, false, false, connection));
				return true;
			}
			
			return false;
		}
		
		/** 타이머로 반복되는 함수 */
		private function _timerFunc(e:TimerEvent):void
		{
			_processData();
		}
		
		/** 수신한 정보를 처리 */
		private function _processData():void
		{
			var obj:Object;
			var connection:GogduNetConnection;
			
			var packetBytes:ByteArray; // 패킷을 읽을 때 쓰는 바이트 배열.
			var regArray:Array; // 정규 표현식으로 찾은 문자열들을 저장해 두는 배열
			var jsonObj:Object // 문자열을 JSON으로 변환할 때 사용하는 객체
			var packetStr:String; // byte을 String으로 변환하여 읽을 때 쓰는 문자열.
			var i:uint;
			
			for each(obj in _connectionTable)
			{
				for each(connection in obj)
				{
					if(connection == null)
					{
						continue;
					}
					
					if(_checkConnect(connection) == true)
					{
						continue;
					}
					
					connection._backupBytes.position = 0;
					if(connection._backupBytes.bytesAvailable <= 0)
					{
						continue;
					}
					
					//packetBytes이 onnection._backupBytes을 참조한다.
					packetBytes = connection._backupBytes;
					
					//만약 AS가 아닌 C# 등과 통신할 경우 엔디안이 다르므로 오류가 날 수 있다. 그걸 방지하기 위함.
					packetBytes.endian = Endian.LITTLE_ENDIAN;
					
					// 정보(byte)를 String으로 읽는다.
					try
					{
						packetBytes.position = 0;
						packetStr = packetBytes.readMultiByte(packetBytes.length, _encoding);
						packetBytes.length = 0; //packetBytes == connection._backupBytes
					}
					catch(e:Error)
					{
						_record.addErrorRecord(e, "It occurred from packet bytes convert to string", true);
						continue;
					}
					
					// 필요 없는 잉여 패킷(잘못 전달되었거나 악성 패킷)이 있으면 제거한다.
					if(_reg2.test(packetStr) == true)
					{
						_record.addRecord("Sensed surplus packets(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")(address:" + connection.address + 
							", port:" + connection.port + ")(str:" + packetStr + ")", true);
						_record.addByteRecord(packetBytes, true);
						dispatchEvent(new GogduNetUDPDataEvent(GogduNetUDPDataEvent.INVALID_PACKET, false, false, connection, null, null, packetBytes));
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
							_record.addRecord("Sensed wrong packets(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")(address:" + connection.address + 
									", port:" + connection.port + ")(str:" + regArray[i] + ")", true);
							dispatchEvent(new GogduNetUDPDataEvent(GogduNetUDPDataEvent.INVALID_PACKET, false, false, connection, null, null, packetBytes));
							continue;
						}
							// 패킷에 오류가 없으면
						else
						{
							if(jsonObj.t == DataType.DEFINITION)
							{
								_record.addRecord("Data received(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")(address:" + connection.address + 
									", port:" + connection.port + ")"/*(type:" + jsonObj.type + ", def:" + 
									jsonObj.def + ")"*/, true);
								dispatchEvent(new GogduNetUDPDataEvent(GogduNetUDPDataEvent.RECEIVE_DATA, false, false, connection, jsonObj.t, jsonObj.df, null));
							}
							else
							{
								_record.addRecord("Data received(elapsedTimeAfterReceived:" + elapsedTimeAfterReceived + ")(address:" + connection.address + 
									", port:" + connection.port + ")"/*(type:" + jsonObj.type + ", def:" + 
									jsonObj.def + ", data:" + jsonObj.data ")"*/, true);
								dispatchEvent(new GogduNetUDPDataEvent(GogduNetUDPDataEvent.RECEIVE_DATA, false, false, connection, jsonObj.t, jsonObj.df, jsonObj.dt));
							}
						}
					}
					
					// 다 처리하고 난 후에도 남아 있는(패킷이 다 오지 않아 처리가 안 된) 정보(byte)를 소켓의 backupBytes에 임시로 저장해 둔다.
					if(packetStr.length > 0)
					{
						packetBytes = connection._backupBytes;
						packetBytes.length = 0;
						packetBytes.position = 0;
						packetBytes.writeMultiByte(packetStr, _encoding);
					}
				}
			}
		}
	} // class
} // package