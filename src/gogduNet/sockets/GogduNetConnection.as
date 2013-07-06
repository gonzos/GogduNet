package gogduNet.sockets
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import gogduNet.events.GogduNetConnectionEvent;
	
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="connectionUpdated", type="gogduNet.events.GogduNetConnectionEvent")]
	
	public class GogduNetConnection extends EventDispatcher
	{
		private var _address:String;
		private var _port:int;
		private var _lastReceivedTime:Number;
		private var _backupByteArray:ByteArray;
		private var _event:GogduNetConnectionEvent;
		
		/** 반드시 address, port 속성을 설정해야 한다. */
		public function GogduNetConnection()
		{
			initialize();
		}
		
		public function initialize():void
		{
			_address = null;
			_port = 0;
			_lastReceivedTime = -1;
			_backupByteArray = new ByteArray();
			_event = new GogduNetConnectionEvent(GogduNetConnectionEvent.CONNECTION_UPDATED, false, false, this);
		}
		
		/** 대상의 address */
		public function get address():String
		{
			return _address;
		}
		internal function setAddress(value:String):void
		{
			_address = value;
		}
		
		/** 대상의 포트 */
		public function get port():int
		{
			return _port;
		}
		internal function setPort(value:int):void
		{
			_port = value;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(ms) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() - _lastReceivedTime;
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
			_lastReceivedTime = getTimer();
			dispatchEvent(_event);
		}
		
		public function dispose():void
		{
			_address = null;
			_backupByteArray = null;
			_event = null;
		}
	}
}