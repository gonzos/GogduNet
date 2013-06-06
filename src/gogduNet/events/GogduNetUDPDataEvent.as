package gogduNet.events
{
	import flash.events.Event;
	
	import gogduNet.sockets.GogduNetConnection;
	
	public class GogduNetUDPDataEvent extends Event
	{
		public static const RECEIVE_DATA:String = "receiveData";
		public static const INVALID_PACKET:String = "invalidPacket";
		
		private var _connection:GogduNetConnection;
		private var _dataType:String;
		private var _dataDefinition:String;
		private var _data:Object;
		
		public function GogduNetUDPDataEvent(eventType:String, bubbles:Boolean=false, cancelable:Boolean=false,
												connection:GogduNetConnection=null, 
												dataType:String=null, dataDefinition:String=null, data:Object=null)
		{
			super(eventType, bubbles, cancelable);
			_connection = connection;
			_dataType = dataType;
			_dataDefinition = dataDefinition;
			_data = data;
		}
		
		public function get connection():GogduNetConnection
		{
			return _connection;
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
			return new GogduNetUDPDataEvent(type, bubbles, cancelable, _connection, _dataType, _dataDefinition, _data);
		}
	}
}