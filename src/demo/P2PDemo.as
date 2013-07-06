package
{
	/**
	 * @author : Siyania (siyania@naver.com) (http://siyania.blog.me/)
	 * @create : Jun 6, 2013
	 */
	import flash.display.Sprite;
	
	import gogduNet.events.GogduNetStatusEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.sockets.GogduNetP2PClient;
	
	public class P2PDemo extends Sprite
	{
		public function P2PDemo()
		{
			var url:String = "your rtmfp url";
			
			var client:GogduNetP2PClient = new GogduNetP2PClient(url, "GogduNet");
			//데이터를 수신할 때 실행되는 이벤트 추가
			client.addEventListener(GogduNetStatusEvent.RECEIVE_DATA, getData);
			//상태 변화, 보고 등 다용도 목적 이벤트 추가
			client.addEventListener(GogduNetStatusEvent.STATUS, onStatus);
			
			var client2:GogduNetP2PClient= new GogduNetP2PClient(url, "GogduNet");
			//데이터를 수신할 때 실행되는 이벤트 추가
			client2.addEventListener(GogduNetStatusEvent.RECEIVE_DATA, getData2);
			
			//연결 시도
			client.connect()
			//연결 시도
			client2.connect();
			
			function onStatus(e:GogduNetStatusEvent):void
			{
				if(e.dataType == DataType.STATUS)
				{
					//p2p 연결에 성공한 경우
					if(e.dataDefinition == "GogduNet.Connect.Success")
					{
						trace("Succeed connect");
					}
					//누군가와 연결된 경우
					else if(e.dataDefinition == "GogduNet.Neighbor.Connect")
					{
						//연결이 안정되었을 때 실행할 이벤트 추가.
						client.addEventListener(GogduNetStatusEvent.STATUS, connectStabilized);
					}
				}
			}
			
			//연결이 안정되었을 때 실행되는 이벤트
			function connectStabilized(e:GogduNetStatusEvent):void
			{
				client.removeEventListener(GogduNetStatusEvent.STATUS, connectStabilized);
				
				//연결이 안정된 경우
				//(연결 직후엔 연결이 불안정하여 전송이 잘 되지 않기 때문에 연결이 안정화된 후에 전송하는 것입니다.)
				if(e.dataDefinition == "GogduNet.Peer.Connection.Stabilized")
				{
					trace(e.peerID, "Connection is stabilized");
					//주의. GogduNetP2PClient의 sendString() 함수는 연결되어 있는 모든 피어에게 패킷을 전송합니다.
					client.sendString("Message", "I Love Miku!!");
				}
				//연결 안정화 확인을 못할 경우
				if(e.dataDefinition == "GogduNet.Peer.Connection.StabilizeFailed")
				{
					trace(e.peerID, "Oops!");
				}
			}
			
			function getData(e:GogduNetStatusEvent):void
			{
				trace("client <-", e.dataType, e.dataDefinition, e.data);
			}
			
			function getData2(e:GogduNetStatusEvent):void
			{
				trace("client2 <-", e.dataType, e.dataDefinition, e.data);
				client2.sendString("Message", "は、はい！");
			}
		}
	}
}