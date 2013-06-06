package gogduNet.sockets
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import gogduNet.events.GogduNetDataEvent;
	import gogduNet.events.GogduNetSocketEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.utils.RecordConsole;
	import gogduNet.utils.makePacket;
	import gogduNet.utils.parsePacket;
	import gogduNet.utils.Encryptor;
	
	/** 연결이 성공한 경우 발생 */
	[Event(name="connect", type="flash.events.Event")]
	/** 서버 등에 의해 비자발적으로 연결이 끊긴 경우 발생 */
	[Event(name="close", type="flash.events.Event")]
	/** 연결 시도가 IOError로 실패한 경우 발생 */
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	/** 연결 시도가 SecurityError로 실패한 경우 발생 */
	[Event(name="securityError", type="flash.events.SecurityErrorEvent")]
	/** 정상적인 데이터를 수신했을 때 발생. 데이터는 가공되어 이벤트로 전달된다. */
	[Event(name="receiveData", type="gogduNet.events.GogduNetDataEvent")]
	/** 정상적이지 않은 데이터를 수신했을 때 발생 */
	[Event(name="invalidPacket", type="gogduNet.events.GogduNetDataEvent")]
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetSocketEvent")]
	
	public class GogduNetClient extends EventDispatcher
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
		private var _socket:Socket;
		/** 서버 address */
		private var _serverAddress:String;
		/** 서버 포트 */
		private var _serverPort:int;
		/** 서버 인코딩 유형(기본값="UTF-8") */
		private var _encoding:String;
		
		// 상태
		/** 현재 연결되어 있는가를 나타내는 bool 값 */
		private var _isConnected:Boolean;
		/** 연결된 지점의 시간을 나타내는 변수 */
		private var _connectedTime:Number;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		private var _backupBytes:ByteArray;
		
		private var _event:GogduNetSocketEvent;
		
		/** <p>serverAddress : 연결할 서버의 address</p>
		 * <p>serverPort : 연결할 서버의 포트</p>
		 * <p>timerInterval : 정보 수신과 연결 검사를 할 때 사용할 타이머의 반복 간격(밀리초 단위)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(여기서 설정한 시간 동안 서버로부터 데이터가 오지 않으면 서버와 연결이 끊긴 것으로 간주한다. 초 단위)</p>
		 * <p>encoding : 통신을 할 때 사용할 인코딩 형식</p>
		 */
		public function GogduNetClient(serverAddress:String, serverPort:int, timerInterval:Number=20,
										connectionDelayLimit:Number=10, encoding:String="UTF-8")
		{
			_timer = new Timer(timerInterval);
			_connectionDelayLimit = connectionDelayLimit;
			_lastReceivedTime = -1;
			_socket = new Socket();
			_serverAddress = serverAddress;
			_serverPort = serverPort;
			_encoding = encoding;
			_isConnected = false;
			_connectedTime = -1;
			_record = new RecordConsole();
			_backupBytes = new ByteArray();
			_event = new GogduNetSocketEvent(GogduNetSocketEvent.CONNECTION_UPDATED, false, false, null, _socket, null);
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
		public function get socket():Socket
		{
			return _socket;
		}
		
		/** 서버의 address를 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get serverAddress():String
		{
			return _serverAddress;
		}
		public function set serverAddress(value:String):void
		{
			if(_isConnected == true)
			{
				return;
			}
			
			_serverAddress = value;
		}
		
		/** 서버의 포트를 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get serverPort():int
		{
			return _serverPort;
		}
		public function set serverPort(value:int):void
		{
			if(_isConnected == true)
			{
				return;
			}
			
			_serverPort = value;
		}
		
		/** 통신 인코딩 유형을 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get encoding():String
		{
			return _encoding;
		}
		public function set encoding(value:String):void
		{
			if(_isConnected == true)
			{
				return;
			}
			
			_encoding = value;
		}
		
		/** 현재 연결되어 있는가를 나타내는 값을 가져온다. */
		public function get isConnected():Boolean
		{
			return _isConnected;
		}
		
		/** 디버그용 기록을 가져온다. */
		public function get record():RecordConsole
		{
			return _record;
		}
		
		/** 연결된 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다. */
		public function get elapsedTimeAfterConnected():Number
		{
			if(_isConnected == false)
			{
				return -1;
			}
			
			return getTimer() / 1000.0 - _connectedTime;
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
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			_socket.removeEventListener(Event.CLOSE, _socketClosed);
			//removeEventListener(Event.ENTER_FRAME, _timerFunc);
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			_timer = null;
			_reg = null;
			_reg2 = null;
			_socket = null;
			_serverAddress = null;
			_encoding = null;
			_record.dispose();
			_record = null;
			_backupBytes = null;
			_event = null;
			
			_isConnected = false;
		}
		
		/** 서버와 연결 */
		public function connect():void
		{
			if(!_serverAddress || _isConnected == true)
			{
				return;
			}
			
			_socket.connect(_serverAddress, _serverPort);
			_socket.addEventListener(Event.CONNECT, _socketConnect);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
		}
		
		private function _socketConnect(e:Event):void
		{
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			
			_connectedTime = getTimer() / 1000.0;
			updateLastReceivedTime();
			_record.addRecord("Connected to server(connectedTime:" + _connectedTime + ")", true);
			
			_socket.addEventListener(Event.CLOSE, _socketClosed);
			//addEventListener(Event.ENTER_FRAME, _timerFunc);
			_timer.start();
			_timer.addEventListener(TimerEvent.TIMER, _timerFunc);
			
			_isConnected = true;
			dispatchEvent(new Event(Event.CONNECT));
		}
		
		private function _socketConnectFail(e:IOErrorEvent):void
		{
			_record.addRecord("Failed connect to server(IOErrorEvent)", true);
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			
			dispatchEvent(e);
		}
		
		private function _socketConnectFail2(e:SecurityErrorEvent):void
		{
			_record.addRecord("Failed connect to server(SecurityErrorEvent)", true);
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			
			dispatchEvent(e);
		}
		
		/** 서버와의 연결을 끊음 */
		public function close():void
		{
			if(_isConnected == false)
			{
				return;
			}
			
			_socket.close();
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			_socket.removeEventListener(Event.CLOSE, _socketClosed);
			//removeEventListener(Event.ENTER_FRAME, _timerFunc);
			
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			
			_record.addRecord("Connection to close(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")", true);
			_isConnected = false;
		}
		
		/** 패킷 형식에 맞지 않는 등의 이유로 전송이 안 된 경우 false를, 그렇지 않으면 true를 반환합니다. */
		public function sendDefinition(definition:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.DEFINITION, definition);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendString(definition:String, data:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.STRING, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendArray(definition:String, data:Array):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.ARRAY, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendInteger(definition:String, data:int):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendUnsignedInteger(definition:String, data:uint):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.UNSIGNED_INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendRationals(definition:String, data:Number):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.RATIONALS, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		public function sendBoolean(definition:String, data:Boolean):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.BOOLEAN, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		/** this data's type is Object or String**/
		public function sendJSON(definition:String, data:Object):Boolean
		{
			if(_isConnected == false)
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
			
			_socket.writeMultiByte(str, _encoding);
			_socket.flush();
			return true;
		}
		
		private function _socketClosed(e:Event):void
		{
			_record.addRecord("Connection to server is disconnected(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")", true);
			_isConnected = false;
			
			_socket.removeEventListener(Event.CONNECT, _socketConnect);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, _socketConnectFail);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _socketConnectFail2);
			_socket.removeEventListener(Event.CLOSE, _socketClosed);
			//removeEventListener(Event.ENTER_FRAME, _timerFunc);
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			
			dispatchEvent(new Event(Event.CLOSE));
		}
		
		/** 타이머로 반복되는 함수 */
		private function _timerFunc(e:TimerEvent):void
		{
			_checkConnect();
			_listen();
		}
		
		/** 연결 상태를 검사 */
		private function _checkConnect():void
		{
			// 일정 시간 이상 전송이 오지 않을 경우 접속이 끊긴 것으로 간주하여 이쪽에서도 접속을 끊는다.
			if(elapsedTimeAfterLastReceived > _connectionDelayLimit)
			{
				_record.addRecord("Connection to close(NoResponding)(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")", true);
				close();
				dispatchEvent(new Event(Event.CLOSE));
			}
		}
		
		/** 정보 수신 */
		private function _listen():void
		{
			var packetBytes:ByteArray; // 패킷을 읽을 때 쓰는 바이트 배열.
			var bytes:ByteArray; // 패킷을 읽을 때 보조용으로 한 번만 쓰는 일회용 문자열.
			var regArray:Array; // 정규 표현식으로 찾은 문자열들을 저장해 두는 배열
			var jsonObj:Object // JSON Object로 전환된 패킷을 담는 객체
			var packetStr:String; // byte을 String으로 변환하여 읽을 때 쓰는 문자열.
			var i:uint;
			
			if(_socket.connected == false)
			{
				return;
			}
			if(_socket.bytesAvailable <= 0)
			{
				return;
			}
			
			// 마지막 연결 시각을 갱신.
			updateLastReceivedTime();
			
			// packetBytes는 socket.packetBytes + socketInSocket의 값을 가지게 된다.
			try
			{
				packetBytes = new ByteArray();
				bytes = _backupBytes;
				bytes.position = 0;
				packetBytes.position = 0;
				packetBytes.writeBytes(bytes, 0, bytes.length);
				_socket.readBytes(packetBytes, packetBytes.length, _socket.bytesAvailable);
				bytes.length = 0; //bytes == _backupBytes
				
				//만약 AS가 아닌 C# 등과 통신할 경우 엔디안이 다르므로 오류가 날 수 있다. 그걸 방지하기 위함.
				packetBytes.endian = Endian.LITTLE_ENDIAN;
			}
			catch(e:Error)
			{
				_record.addErrorRecord(e, "It occurred from read to socket's packet", true);
				return;
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
				return;
			}
			
			// 필요 없는 잉여 패킷(잘못 전달되었거나 악성 패킷)이 있으면 제거한다.
			if(_reg2.test(packetStr) == true)
			{
				_record.addRecord("Sensed surplus packet(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(str:" + packetStr + ")", true);
				_record.addByteRecord(packetBytes, true);
				dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.INVALID_PACKET, false, false, null, _socket, null, null, packetBytes));
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
					_record.addRecord("Sensed wrong packets(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(str:" + regArray[i] + ")", true);
					_record.addByteRecord(packetBytes, true);
					dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.INVALID_PACKET, false, false, null, _socket, null, null, packetBytes));
					continue;
				}
				// 패킷에 오류가 없으면
				else
				{
					if(jsonObj.t == DataType.DEFINITION)
					{
						_record.addRecord("Data received(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")"/*(type:" + 
							jsonObj.type + ", def:" + jsonObj.def + ")"*/, true);
						dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, null, _socket, jsonObj.t, jsonObj.df, null));
					}
					else
					{
						_record.addRecord("Data received(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")"/*(type:" + 
							jsonObj.type + ", def:" + jsonObj.def + ", data:" + jsonObj.data + ")"*/, true);
						dispatchEvent(new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, null, _socket, jsonObj.t, jsonObj.df, jsonObj.dt));
					}
				}
			}
			
			// 다 처리하고 난 후에도 남아 있는(패킷이 다 오지 않아 처리가 안 된) 정보(byte)를 backupBytes에 임시로 저장해 둔다.
			if(packetStr.length > 0)
			{
				_backupBytes.length = 0;
				_backupBytes.position = 0;
				_backupBytes.writeMultiByte(packetStr, _encoding);
			}
		}
	} // class
} // package