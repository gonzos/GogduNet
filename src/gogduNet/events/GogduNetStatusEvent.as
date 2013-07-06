package gogduNet.events
{
	import flash.events.Event;
	import flash.net.Socket;
	
	import gogduNet.sockets.GogduNetSocket;
	
	/** <strong>GogduNetStatusEvent.STATUS</strong>
	 * 
	 * 	<ul>
	 * 		<li>dataType == DataType.STATUS</br>　dataDefinition ==
	 * 			<ul>
	 * 				<li>"GogduNet.UnpermittedConnection" : 허용되지 않은 연결 시도가 감지된 경우 발생한다.</li>
	 * 				<li>"GogduNet.Peer.ConnectionUpdated" : GogduNetPeer의 연결이 갱신(데이터를 수신)되면 발생한다.(내가 데이터를 전송할 땐 발생하지 않는다)</li>
	 * 				<li>"GogduNet.Peer.FindPeerStreamFailed" : GogduNetPeer의 searchForPeerStream()을 실행한 후, 전송용 스트림(NetStream)을 찾는 데 실패한 경우 발생한다.</li>
	 * 				<li>"GogduNet.Peer.FoundPeerStream" : GogduNetPeer의 searchForPeerStream()을 실행한 후, 전송용 스트림(NetStream)을 찾는 데 성공한 경우 발생한다. 또한 이는 연결이 안정되었음을 의미하므로, 연결이 안정된 후 정보를 보내고자 할 때 쓸 수 있다. (peerID:피어 자신의 peerID, data:찾은 스트림)</li>
	 * 				<li>"GogduNet.ConnectionUpdated" : GogduNetP2PClient의 연결이 갱신(데이터를 수신)되면 발생한다.(내가 데이터를 전송할 땐 발생하지 않는다)</li>
	 * 				<li>"GogduNet.Connect.Success" : 연결이 성공하면 발생한다.</li>
	 * 				<li>"GogduNet.Neighbor.Disconnect" : NetGroup에서 누군가가 나가면 발생한다. (peerID:나간 피어의 peerID)</li>
	 * 				<li>"GogduNet.Neighbor.Connect" : 누군가가 나와 연결된 경우 발생한다.(NetGroup에 누군가가 접속하거나, 누군가가 접속되어 있는 NetGroup에 내가 접속한 경우) (peerID:연결된 피어의 peerID)</li>
	 * 				<li>"GogduNet.Neighbor.Disconnect.NoResponding" : (GogduNetP2PClient) 특정 피어에게서 connectionDelayLimit 속성에서 정의된 시간 동안 아무 데이터도 받지 못한 경우 자동으로 연결을 끊는데, 이때 발생한다. (peerID:끊은 피어의 peerID)</li>
	 * 				<li>"GogduNet.Peer.Connection.Stabilized" : 특정 피어와의 연결이 안정되면 발생한다. (이 이벤트가 발생했더라도 나중에 다시 연결이 불안정해질 수가 있다.) (peerID:안정된 피어의 peerID)</li>
	 * 				<li>"GogduNet.Peer.Connection.StabilizeFailed" : 특정 피어의 안정화 확인 작업이 실패하면 발생한다. (연결 후 자동으로 시도되는 안정화 확인 작업 중에서 안정화가 되지 않았다는 걸 의미하므로, 이 이벤트가 발생했더라도 나중에 연결이 안정될 수 있다) (peerID:안정된 피어의 peerID)</li>
	 * 				<li>flash.events.NetStatusEvent 이벤트 중 info 속성의 level 속성이 "status"인 이벤트가 발생한 경우에 (dataDefinition:NetStatusEvent.info.code, data:NetStatusEvent 객체)로 이벤트가 발생한다.</li>
	 * 			</ul>
	 * 		</li>
	 * 		<li>dataType == DataType.ERROR</br>　dataDefinition ==
	 * 			<ul>
	 * 				<li>"GogduNet.Connect.Failed" : 연결에 실패한 경우 발생한다.
	 * 				<li>"GogduNet.Disconnect" : 연결이 비자발적으로 끊긴 경우에 발생한다. (data:(연결이 끊긴 이유))
	 * 					<ul>연결이 끊긴 이유
	 * 						<li>"NetConnection.Connect.AppShutdown"</li>
	 * 						<li>"NetConnection.Connect.InvalidApp"</li>
	 * 						<li>"NetConnection.Connect.Rejected"</li>
	 * 						<li>"NetConnection.Connect.IdleTimeout"</li>
	 * 					</ul>
	 * 				<li>flash.events.NetStatusEvent 이벤트 중 info 속성의 level 속성이 "error"인 이벤트가 발생한 경우에 (dataDefinition:NetStatusEvent.info.code, data:NetStatusEvent 객체)로 이벤트가 발생한다.</li>
	 * 			</ul>
	 * 		</li>
	 * 	</ul>
	 * 
	 * <strong></br>GogduNetStatusEvent.RECEIVE_DATA</strong>
	 * </br>(GogduNetP2PClient) 데이터를 수신한 경우에 발생한다. (peerID:데이터를 전송한 피어의 peerID, dataType:데이터의 type 부분, dataDefinition:data의 def 부분, data:data의 실제 정보 부분)</br>
	 * 
	 * <strong></br>GogduNetStatusEvent.INVALID_PACKET</strong>
	 * 
	 * </br>잘못된 패킷을 수신한 경우에 발생한다.
	 * 	<ul>dataDefinition ==
	 * 		<li>"GogduNet.InvalidPacket.Surplus" : 필요 없는 잉여 패킷이 감지된 경우 발생한다. (peerID:패킷을 전송한 피어의 peerID, data:문제가 된 패킷을 포함한 전체 패킷 문자열)</li>
	 * 		<li>"GogduNet.InvalidPacket.Wrong" : 그 외에 패킷에 문제가 있는 경우 발생한다. (peerID:패킷을 전송한 피어의 peerID, data:문제가 된 패킷을 포함한 전체 패킷 문자열)</li>
	 * 	</ul>
	 */
	public class GogduNetStatusEvent extends Event
	{
		public static const STATUS:String = "status";
		public static const RECEIVE_DATA:String = "receiveData";
		public static const INVALID_PACKET:String = "invalidPacket";
		
		private var _peerID:String;
		private var _dataType:String;
		private var _dataDefinition:String;
		private var _data:Object;
		
		public function GogduNetStatusEvent(eventType:String, bubbles:Boolean=false, cancelable:Boolean=false,
												peerID:String=null, dataType:String=null, dataDefinition:String=null, data:Object=null)
		{
			super(eventType, bubbles, cancelable);
			_peerID = peerID;
			_dataType = dataType;
			_dataDefinition = dataDefinition;
			_data = data;
		}
		
		public function get peerID():String
		{
			return _peerID;
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
			return new GogduNetStatusEvent(type, bubbles, cancelable, _peerID, _dataType, _dataDefinition, _data);
		}
	}
}