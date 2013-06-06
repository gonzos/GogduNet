package
{
	/**
	 * @author : Siyania (siyania@naver.com)
	 * @create : Jun 6, 2013
	 */
	import flash.display.Sprite;
	
	import gogduNet.events.GogduNetUDPDataEvent;
	import gogduNet.sockets.GogduNetUDPClient;
	
	public class UDPDemo extends Sprite
	{
		public function UDPDemo()
		{
			var client:GogduNetUDPClient= new GogduNetUDPClient("127.0.0.1", 3333);
			//데이터를 수신할 때 실행되는 이벤트 추가
			client.addEventListener(GogduNetUDPDataEvent.RECEIVE_DATA, getData);
			
			var client2:GogduNetUDPClient= new GogduNetUDPClient("127.0.0.1", 4444);
			//데이터를 수신할 때 실행되는 이벤트 추가
			client2.addEventListener(GogduNetUDPDataEvent.RECEIVE_DATA, getData2);
			
			//정보 수신 시작
			client.receive();
			//정보 수신 시작
			client2.receive();
			
			client.sendString("GogduNet.Message", "I Love Miku!!", "127.0.0.1", 4444);
			
			function getData(e:GogduNetUDPDataEvent):void
			{
				trace("client <-", e.dataType, e.dataDefinition, e.data);
			}
			
			function getData2(e:GogduNetUDPDataEvent):void
			{
				trace("client2 <-", e.dataType, e.dataDefinition, e.data);
				client2.sendString("GogduNet.Message", "は、はい！", "127.0.0.1", 3333);
			}
		}
	}
}