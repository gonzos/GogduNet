GogduNet
=====

**GogduNet** - Flash AS3 Communication Library for **TCP** and **UDP** and **P2P**

Version 1.10 (2013.7.8.)

Made by **Siyania**
(siyania@naver.com)
(http://siyania.blog.me/)

몇 줄의 코드만으로 간단하게 서버나 클라이언트를 생성할 수 있으며, 자동으로 잘못된 패킷을 걸러 내고, 데이터를 패킷 단위로 구분하여 사용자에게 알려 줍니다.
자세한 설명은 GogduNetServer와 그 외 클래스의 상단에 적혀 있습니다.

(TCP) GogduNetServer : AIR 3.0 Desktop, AIR 3.8

(TCP) GogduNetClient : Flash Player 11, AIR 3.0

(TCP) GogduNetPolicyServer : AIR 3.0 Desktop, AIR 3.8

(TCP) GogduNetBinaryServer : AIR 3.0 Desktop, AIR 3.8

(TCP) GogduNetBinaryClient : Flash Player 11, AIR 3.0

(UCP) GogduNetUDPClient : AIR 3.0 Desktop, AIR 3.8

(P2P) GogduNetP2PClient : Flash Player 11, AIR 3.0

TCPDemo.as
-----

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

UDPDemo.as
-----

package
{
	/**
	 * @author : Siyania (siyania@naver.com) (http://siyania.blog.me/)
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
			
			client.sendString("Message", "I Love Miku!!", "127.0.0.1", 4444);
			
			function getData(e:GogduNetUDPDataEvent):void
			{
				trace("client <-", e.dataType, e.dataDefinition, e.data);
			}
			
			function getData2(e:GogduNetUDPDataEvent):void
			{
				trace("client2 <-", e.dataType, e.dataDefinition, e.data);
				client2.sendString("Message", "は、はい！", "127.0.0.1", 3333);
			}
		}
		/*
		Console)
		client2 <- str Message I Love Miku!!
		client <- str Message は、はい！
		*/
	}
}

P2PDemo.as
-----

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

BinaryTCPDemo.as
-----

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
