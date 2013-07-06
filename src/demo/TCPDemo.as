package
{
	/**
	 * @author : Siyania (siyania@naver.com) (http://siyania.blog.me/)
	 * @create : Jun 6, 2013
	 */
	import flash.display.Sprite;
	import flash.events.Event;
	
	import gogduNet.events.GogduNetDataEvent;
	import gogduNet.sockets.GogduNetClient;
	import gogduNet.sockets.GogduNetServer;
	
	public class TCPDemo extends Sprite
	{
		public function TCPDemo()
		{
			var server:GogduNetServer = new GogduNetServer("127.0.0.1", 3333);
			//데이터를 수신했을 때 실행되는 이벤트 추가
			server.addEventListener(GogduNetDataEvent.RECEIVE_DATA, serverGetData);
			
			var client:GogduNetClient = new GogduNetClient("127.0.0.1", 3333);
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
				client.sendString("Message", "I Love Miku!!");
			}
			
			function serverGetData(e:GogduNetDataEvent):void
			{
				trace("server <-", e.dataType, e.dataDefinition, e.data);
				server.sendString(e.socket, "Message", "は、はい！");
			}
			
			function clientGetData(e:GogduNetDataEvent):void
			{
				trace("client <-", e.dataType, e.dataDefinition, e.data);
			}
		}
		/*
		Console)
		server <- str Message I Love Miku!!
		client <- def GogduNet.Connect.Success null
		client <- str Message は、はい！
		*/
	}
}