package gogduNet.events
{
	import flash.events.Event;
	import flash.net.Socket;
	
	import gogduNet.sockets.GogduNetSocket;
	
	public class GogduNetDataEvent extends Event
	{
		public static const RECEIVE_DATA:String = "receiveData";
		public static const INVALID_PACKET:String = "invalidPacket";
		
		/** only GogduNetBinaryServer */
		public static const PROGRESS_DATA:String = "progressData";
		
		private var _socket:GogduNetSocket;
		private var _nativeSocket:Socket;
		private var _dataType:String;
		private var _dataDefinition:String;
		private var _data:Object;
		
		public function GogduNetDataEvent(eventType:String, bubbles:Boolean=false, cancelable:Boolean=false,
												socket:GogduNetSocket=null, nativeSocket:Socket=null,
												dataType:String=null, dataDefinition:String=null, data:Object=null)
		{
			super(eventType, bubbles, cancelable);
			_socket = socket;
			_nativeSocket = nativeSocket;
			_dataType = dataType;
			_dataDefinition = dataDefinition;
			_data = data;
		}
		
		public function get socket():GogduNetSocket
		{
			return _socket;
		}
		
		public function get nativeSocket():Socket
		{
			return _nativeSocket;
		}
		
		public function get dataType():String
		{
			return _dataType;
		}
		
		public function get dataDefinition():String
		{
			return _dataDefinition;
		}
		
		public function get data():Object
		{
			return _data;
		}
		
		override public function clone():Event
		{
			return new GogduNetDataEvent(type, bubbles, cancelable, _socket, _nativeSocket, _dataType, _dataDefinition, _data);
		}
	}
}