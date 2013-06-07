package gogduNet.sockets
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import gogduNet.events.GogduNetSocketEvent;
	
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetSocketEvent")]
	
	public class GogduNetSocket extends EventDispatcher
	{
		private var _socket:Socket;
		private var _id:String; //식별용 문자열
		private var _lastReceivedTime:Number;
		private var _backupByteArray:ByteArray;
		private var _event:GogduNetSocketEvent;
		
		/** 반드시 nativeSocket, id 속성을 설정해야 한다. */
		public function GogduNetSocket()
		{
			initialize();
		}
		
		public function initialize():void
		{
			_socket = null;
			_id = null;
			_lastReceivedTime = -1;
			_backupByteArray = new ByteArray();
			_event = new GogduNetSocketEvent(GogduNetSocketEvent.CONNECTION_UPDATED, false, false, this, null, null);
		}
		
		public function get nativeSocket():Socket
		{
			return _socket;
		}
		internal function setNativeSocket(value:Socket):void
		{
			if(_socket)
			{
				_socket.removeEventListener(Event.CLOSE, _onClose);
			}
			
			_socket = value;
			_socket.addEventListener(Event.CLOSE, _onClose);
		}
		
		/** 이 소켓의 address (for AIR) */
		public function get address():String
		{
			return _socket.remoteAddress;
		}
		
		/** 이 소켓의 포트 (for AIR) */
		public function get port():int
		{
			return _socket.remotePort;
		}
		
		/** 식별용 문자열을 가져오거나 설정한다. */
		public function get id():String
		{
			return _id;
		}
		internal function setID(value:String):void
		{
			_id = value;
		}
		
		/** 현재 연결되어 있는가를 나타내는 값을 가져온다. */
		public function get isConnected():Boolean
		{
			return _socket.connected;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(초 단위) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() / 1000.0 - _lastReceivedTime;
		}
		
		/** 통신을 할 때 아직 처리하지 못 한 패킷을 보관하는 바이트 배열이다.
		 * 배열이 수정되면 오류가 날 수 있으므로 건드리지 않는 것이 좋다.
		 */
		internal function get _backupBytes():ByteArray
		{
			return _backupByteArray;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * 서버가 이 소켓에게서 패킷을 받을 경우, 자동으로 이 함수가 실행되어 갱신된다.
		 * (서버가 이 소켓에게 패킷을 보낸 경우는 갱신되지 않는다.)
		 */
		public function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer() / 1000.0;
			dispatchEvent(_event);
		}
		
		private function _onClose(e:Event):void
		{
			dispatchEvent(e);
		}
		
		public function dispose():void
		{
			_socket.removeEventListener(Event.CLOSE, _onClose);
			_socket = null;
			_id = null;
			_backupByteArray = null;
			_event = null;
		}
	}
}
