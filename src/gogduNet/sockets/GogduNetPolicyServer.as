package gogduNet.sockets
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import gogduNet.events.GogduNetSocketEvent;
	import gogduNet.utils.RecordConsole;
	
	/** 허용되지 않은 대상에게서 정보가 전송되면 발생 */
	[Event(name="unpermittedConnection", type="gogduNet.events.GogduNetSocketEvent")]
	/** 운영체제 등에 의해 비자발적으로 연결이 끊긴 경우 발생 */
	[Event(name="close", type="flash.events.Event")]
	/** 특정 소켓이 성공적으로 접속한 경우 발생 */
	[Event(name="connect", type="gogduNet.events.GogduNetSocketEvent")]
	/** 특정 소켓의 연결이 끊긴 경우 발생 */
	[Event(name="close", type="gogduNet.events.GogduNetSocketEvent")]
	
	public class GogduNetPolicyServer extends EventDispatcher
	{
		// 서버 설정
		/** 서버 소켓 */
		private var _serverSocket:ServerSocket;
		/** 서버 address */
		private var _serverAddress:String;
		/** 서버 포트 */
		private var _serverPort:int;
		
		// 서버 상태
		/** 서버가 실행 중인지를 나타내는 bool 값 */
		private var _run:Boolean;
		/** 서버가 시작된 지점의 시간을 나타내는 변수 */
		private var _runnedTime:Number;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		private var _policyStr:String;
		
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체 */
		private var _connectionSecurity:GogduNetConnectionSecurity;
		
		/** 정책 파일 전송용 서버 */
		public function GogduNetPolicyServer(serverAddress:String, serverPort:int=843, connectionSecurity:GogduNetConnectionSecurity=null)
		{
			_serverSocket = new ServerSocket();
			_serverAddress = serverAddress;
			_serverPort = serverPort;
			_run = false;
			_runnedTime = -1;
			_record = new RecordConsole();
			_policyStr = "<?xml version='1.0'?><cross-domain-policy><allow-access-from domain='" + _serverAddress + "' to-ports='" + _serverPort + "'/></cross-domain-policy>";
			
			if(connectionSecurity == null)
			{
				connectionSecurity = new GogduNetConnectionSecurity(false);
			}
			_connectionSecurity = connectionSecurity;
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
		
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체를 가져오거나 설정한다. */
		public function get connectionSecurity():GogduNetConnectionSecurity
		{
			return _connectionSecurity;
		}
		public function set connectionSecurity(value:GogduNetConnectionSecurity):void
		{
			_connectionSecurity = value;
		}
		
		/** 서버가 실행 중인지를 나타내는 값을 가져온다. */
		public function get isRunning():Boolean
		{
			return _run;
		}
		
		/** 디버그용 기록을 가져온다. */
		public function get record():RecordConsole
		{
			return _record;
		}
		
		/** 서버가 시작된 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다.(ms) */
		public function get elapsedTimeAfterRun():Number
		{
			if(_run == false)
			{
				return -1;
			}
			
			return _runnedTime - getTimer();
		}
		
		// public function
		public function dispose():void
		{
			_serverSocket.close();
			_serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.removeEventListener(Event.CLOSE, _close);
			_serverSocket = null;
			_serverAddress = null;
			_record.dispose();
			_record = null;
			_connectionSecurity.dispose();
			_connectionSecurity = null;
		}
		
		/** 서버 작동 시작 */
		public function run():void
		{
			if(!_serverAddress || _serverPort == 0 || _run == true)
			{
				return;
			}
			
			_run = true;
			_runnedTime = getTimer();
			_serverSocket.bind(_serverPort, _serverAddress);
			_serverSocket.listen();
			_serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.addEventListener(Event.CLOSE, _close);
			_record.addRecord("Opened server(runnedTime:" + _runnedTime + ")", true);
		}
		
		/** 운영체제에 의해 소켓이 닫힘 */
		private function _close():void
		{
			_serverSocket.close();
			_serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.removeEventListener(Event.CLOSE, _close);
			
			_record.addRecord("Closed server by OS(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")", true);
			_run = false;
			dispatchEvent(new Event(Event.CLOSE));
		}
		
		/** 서버 작동 중지 */
		public function close():void
		{
			if(_run == false)
			{
				return;
			}
			
			_serverSocket.close();
			_serverSocket.removeEventListener(ServerSocketConnectEvent.CONNECT, _socketConnect);
			_serverSocket.removeEventListener(Event.CLOSE, _close);
			_serverSocket = new ServerSocket(); //ServerSocket is non reusable after ServerSocket.close()
			
			_record.addRecord("Closed server(elapsedTimeAfterRun:" + elapsedTimeAfterRun + ")", true);
			_run = false;
		}
		
		/** 클라이언트 접속 */
		private function _socketConnect(e:ServerSocketConnectEvent):void
		{
			var socket:Socket = e.socket as Socket;
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
				_record.addRecord("Sensed unpermitted connection(address:" + socket.remoteAddress + 
					", port:" + socket.remotePort + ")", true);
				dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.UNPERMITTED_CONNECTION, false, false, socket, null, null);
				socket.close();
				return;
			}
			
			e.socket.addEventListener(ProgressEvent.SOCKET_DATA, _onSocketData);
			_record.addRecord("Client connected(address:" + socket.remoteAddress + ", port:" + socket.remotePort + ")", true);
			dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CONNECT, false, false, null, socket, null));
		}
		
		private function _onSocketData(e:ProgressEvent):void
		{
			var socket:Socket = e.currentTarget as Socket;
			socket.removeEventListener(ProgressEvent.SOCKET_DATA, _onSocketData);
			
			socket.writeUTFBytes(_policyStr);
			socket.writeByte(0);
			socket.flush();
			setTimeout(_closeSocket, 5000, socket);
			
			_record.addRecord("Send policy file(address:" + socket.remoteAddress + ", port:" + socket.remotePort + ")", true);
		}
		
		/** 소켓의 연결을 끊음 */
		private function _closeSocket(socket:Socket):void
		{
			try
			{
				socket.close();
				dispatchEvent(new GogduNetSocketEvent(GogduNetSocketEvent.CLOSE, false, false, null, socket, GogduNetSocketEvent.INFO_NORMAL_CLOSE));
			}
			catch(e:Error)
			{
				_record.addErrorRecord(e, "It occurred from forced close connection", true);
			}
		}
	} // class
} // package