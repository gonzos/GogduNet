package gogduNet.events
{
	import flash.events.Event;
	
	import gogduNet.sockets.GogduNetConnection;
	
	public class GogduNetConnectionEvent extends Event
	{
		public static const UNPERMITTED_CONNECTION:String = "unpermittedConnection";
		public static const DATA_REMOVED:String = "dataRemoved";
		public static const CONNECTION_UPDATED:String = "connectionUpdated";
		
		private var _connection:GogduNetConnection;
		
		public function GogduNetConnectionEvent(eventType:String, bubbles:Boolean=false, cancelable:Boolean=false,
												connection:GogduNetConnection=null)
		{
			super(eventType, bubbles, cancelable);
			_connection = connection;
		}
		
		public function get connection():GogduNetConnection
		{
			return _connection;
		}
		
		override public function clone():Event
		{
			return new GogduNetConnectionEvent(type, bubbles, cancelable, _connection);
		}
	}
}