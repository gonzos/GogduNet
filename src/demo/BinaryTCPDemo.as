package
{
	/**
	 * @author : Siyania (siyania@naver.com) (http://siyania.blog.me/)
	 * @create : July 6, 2013
	 */
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.utils.ByteArray;
	
	import gogduNet.events.GogduNetDataEvent;
	import gogduNet.sockets.GogduNetBinaryClient;
	import gogduNet.sockets.GogduNetBinaryServer;
	
	public class BinaryTCPDemo extends Sprite
	{
		public function BinaryTCPDemo()
		{
			var server:GogduNetBinaryServer = new GogduNetBinaryServer("127.0.0.1", 3333);
			//데이터를 수신했을 때 실행되는 이벤트 추가
			server.addEventListener(GogduNetDataEvent.RECEIVE_DATA, serverGetData);
			
			var client:GogduNetBinaryClient = new GogduNetBinaryClient("127.0.0.1", 3333);
			//서버에 성공적으로 연결되었을 때 발생하는 이벤트 추가
			client.addEventListener(Event.CONNECT, onConnect);
			//데이터를 수신했을 때 실행되는 이벤트 추가
			client.addEventListener(GogduNetDataEvent.RECEIVE_DATA, clientGetData);
			
			//서버 시작
			server.run();
			//클라이언트를 지정된 서버에 연결 시도
			client.connect();
			
			function onConnect(e:Event):void
			{
				var bytes:ByteArray = new ByteArray();
				bytes.writeMultiByte("I Love Miku!!", "UTF-8");
				
				client.sendBytes("Message", bytes);
			}
			
			function serverGetData(e:GogduNetDataEvent):void
			{
				var data:ByteArray = e.data as ByteArray;
				var str:String = data.readMultiByte(data.length, "UTF-8");
				
				trace("Receive : server <-", e.dataType, e.dataDefinition, str);
				
				var bytes:ByteArray = new ByteArray();
				bytes.writeMultiByte("は、はい！", "UTF-8");
				
				server.sendBytes(e.socket, "Message", bytes);
			}
			
			function clientGetData(e:GogduNetDataEvent):void
			{
				var data:ByteArray = e.data as ByteArray;
				var str:String = data.readMultiByte(data.length, "UTF-8");
				
				trace("Receive : client <-", e.dataType, e.dataDefinition, str);
			}
		}
		/*
			Console)
			Receive : server <- bts Message I Love Miku!!
			Receive : client <- bts GogduNet.Connect.Success
			Receive : client <- bts Message は、はい！
		*/
	}
}