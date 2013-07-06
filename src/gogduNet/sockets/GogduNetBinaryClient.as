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
	import gogduNet.utils.Encryptor;
	
	/** 연결이 성공한 경우 발생 */
	[Event(name="connect", type="flash.events.Event")]
	/** 서버 등에 의해 비자발적으로 연결이 끊긴 경우 발생 */
	[Event(name="close", type="flash.events.Event")]
	/** 연결 시도가 IOError로 실패한 경우 발생 */
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	/** 연결 시도가 SecurityError로 실패한 경우 발생 */
	[Event(name="securityError", type="flash.events.SecurityErrorEvent")]
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
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetSocketEvent")]
	
	public class GogduNetBinaryClient extends EventDispatcher
	{
		private var _timer:Timer;
		
		// 설정
		/** 최대 연결 지연 한계 */
		private var _connectionDelayLimit:Number;
		
		/** 서버와 마지막으로 통신한 시각(정확히는 마지막으로 서버로부터 정보를 전송 받은 시각) */
		private var _lastReceivedTime:Number;
		
		/** 소켓 */
		private var _socket:Socket;
		/** 연결할 서버의 address */
		private var _serverAddress:String;
		/** 연결할 서버의 포트 */
		private var _serverPort:int;
		/** 인코딩 유형(기본값="UTF-8") */
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
		 * <p>timerInterval : 정보 수신과 연결 검사를 할 때 사용할 타이머의 반복 간격(ms)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(ms)(여기서 설정한 시간 동안 서버로부터 데이터가 오지 않으면 서버와 연결이 끊긴 것으로 간주한다.)</p>
		 * <p>encoding : 프로토콜 문자열의 변환에 사용할 인코딩 형식</p>
		 */
		public function GogduNetBinaryClient(serverAddress:String, serverPort:int, timerInterval:Number=100,
										connectionDelayLimit:Number=10000, encoding:String="UTF-8")
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
			
			return getTimer() - _connectedTime;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다. */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * (서버에게서 정보가 들어온 경우 자동으로 이 함수가 실행되어 갱신된다.)
		 */
		public function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer();
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
			
			_connectedTime = getTimer();
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
		
		/** 2진 데이터를 전송한다. 함수 내부에서 자동으로 데이터에 헤더를 붙이지만, 이벤트로 데이터를 넘길 때 헤더가 자동으로 제거되므로
		 * 신경 쓸 필요는 없다. 그리고 definition(프로토콜 문자열)은 암호화되어 전송되고, 받았을 때 복호화되어 이벤트로 넘겨진다. 이
		 * 역시 클래스 내부에서 자동으로 처리되므로 신경 쓸 필요는 없다.(Encryptor 클래스를 수정하여 암호화 부분 수정 가능)<br/>
		 * ( 한 번에 전송할 수 있는 data의 최대 길이는 uint로 표현할 수 있는 최대값인 4294967295(=4GB)이며,
		 * definition 문자열의 최대 길이도 uint로 표현할 수 있는 최대값인 4294967295이다. )</br>
		 * (data 인자에 null을 넣으면, data는 길이가 0으로 전송된다.
		 */
		public function sendBytes(definition:String, data:ByteArray=null):Boolean
		{
			if(_isConnected == false)
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
			
			_socket.writeBytes( packet, 0, packet.length );
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
			var bytes:ByteArray; // 패킷을 읽을 때 보조용으로 쓰는 바이트 배열.
			
			var size:uint; //헤더에서 뽑아낸 파일의 최종 크기
			var protocolLength:uint; //헤더에서 뽑아낸 프로토콜 문자열의 길이
			var protocol:String; //프로토콜 문자열
			var data:ByteArray; //최종 데이터
			
			if(_socket.connected == false)
			{
				return;
			}
			if(_socket.bytesAvailable <= 0)
			{
				return;
			}
			
			// 서버의 마지막 연결 시각을 갱신.
			updateLastReceivedTime();
			
			packetBytes = new ByteArray();
			bytes = _backupBytes;
			bytes.position = 0;
			packetBytes.position = 0;
			packetBytes.writeBytes(bytes, 0, bytes.length);
			//만약 AS가 아닌 C# 등과 통신할 경우 엔디안이 다르므로 오류가 날 수 있다. 그걸 방지하기 위함.
			_socket.endian = Endian.LITTLE_ENDIAN;
			_socket.readBytes(packetBytes, packetBytes.length, _socket.bytesAvailable);
			bytes.length = 0; //bytes == _backupBytes
			
			//헤더가 다 전송되지 않은 경우
			if(packetBytes.length < 8)
			{
				packetBytes.position = 0;
				dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.PROGRESS_DATA, false, false, 
					null, _socket, DataType.BYTES, null, packetBytes) );
			}
			//패킷 바이트의 길이가 8 이상일 경우(즉, 크기 헤더와 프로토콜 문자열 길이 헤더가 있는 경우), 반복
			while(packetBytes.length >= 8)
			{
				packetBytes.position = 0;
				
				try
				{
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
				
				//프로토콜 문자열 길이 이상 전송 된 경우
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
					
					//원래 사이즈만큼, 완전히 전송이 된 경우
					//(bytesAvailable == length - position)
					if(packetBytes.bytesAvailable >= size)
					{
						data = new ByteArray();
						data.writeBytes( packetBytes, packetBytes.position, size );
						data.position = 0;
						
						_record.addRecord("Data received(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")", true);
						
						dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.RECEIVE_DATA, false, false, 
							null, _socket, DataType.BYTES, protocol, data) );
						
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
							null, _socket, DataType.BYTES, protocol, data) );
					}
				}
				//프로토콜 정보가 다 전송되지 않은 경우
				else
				{
					packetBytes.position = 0;
					dispatchEvent( new GogduNetDataEvent(GogduNetDataEvent.PROGRESS_DATA, false, false, 
						null, _socket, DataType.BYTES, null, packetBytes) );
				}
			}
			
			_backup(_backupBytes, packetBytes);
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