package gogduNet.sockets
{
	import flash.events.EventDispatcher;
	import flash.net.NetStream;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import gogduNet.events.GogduNetStatusEvent;
	import gogduNet.sockets.DataType;
	
	/** 연결이 업데이트(정보를 수신)되면 발생 */
	[Event(name="status", type="gogduNet.events.GogduNetStatusEvent")]
	
	public class GogduNetPeer extends EventDispatcher
	{
		private var _netStream:NetStream;
		private var _peerStream:NetStream;
		private var _id:String;
		private var _lastReceivedTime:Number;
		private var _event:GogduNetStatusEvent;
		private var _parent:GogduNetP2PClient;
		
		/** 반드시 netStream, id 속성을 설정해야 한다. */
		public function GogduNetPeer()
		{
			initialize();
		}
		
		public function initialize():void
		{
			_netStream = null;
			_peerStream = null;
			_id = null;
			_lastReceivedTime = -1;
			_event = new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, "GogduNet.Peer.ConnectionUpdated", null);
			_parent = null;
		}
		
		internal function _setParent(target:GogduNetP2PClient):void
		{
			_parent = target;
		}
		
		public function get netStream():NetStream
		{
			return _netStream;
		}
		internal function setNetStream(value:NetStream):void
		{
			_netStream = value;
		}
		
		/** 전송용 피어를 가져온다.
		 * 단, 연결한 후 자신의 전송용 피어를 찾는 데에 시간이 걸리므로 연결 후 일정 시간 동안은 null값을 반환한다. */
		public function get peerStream():NetStream
		{
			return _peerStream;
		}
		
		/** 피어의 id (GogduNetPeer.id ≠ GogduNetPeer.peerID) */
		public function get peerID():String
		{
			if(!_netStream)
			{
				return null;
			}
			
			return _netStream.farID;
		}
		
		/*public function get address():String
		{
			return _socket.remoteAddress;//임시
			return "";
		}
		/*public function set address(value:String)
		{
			_address = value;
		}*/
		
		/** 식별용 id(GogduNetPeer.id ≠ GogduNetPeer.peerID)를 가져오거나 설정한다. */
		public function get id():String
		{
			return _id;
		}
		internal function setID(value:String):void
		{
			_id = value;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(초 단위) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() / 1000.0 - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * 서버가 이 소켓에게서 패킷을 받을 경우, 자동으로 이 함수가 실행되어 갱신된다.
		 * (서버가 이 소켓에게 패킷을 보낸 경우는 갱신되지 않는다.)
		 */
		public function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer() / 1000.0;
			dispatchEvent(_event);
		}
		
		/** 보안상 수신한 peerID를 쓰지 않고 직접 여기서 peerID를 얻어 쓰기 위해 한 번 거쳐 간다. */
		internal function _getData(jsonStr:String):void
		{
			_parent._getData(peerID, jsonStr);
		}
		
		/** <p>자신의 전송용 스트림을 찾아서 peerStream 함수의 반환값으로 설정합니다.
		 * 연결 직후 자동으로 이 함수가 실행되나, 불안정한 연결 때문에 찾는 데에 약간의 시간이 걸립니다.</p>
		 * <p>findStream 인수는 자신의 전송용 스트림을 찾기 위해 peerStreams 속성을 가져올 스트림입니다.</p>
		 * <p>tryNum 인수는 몇 번 탐색을 시도할 것인지를 설정합니다. tryNum 인수만큼 시도해도 찾을 수 없으면 탐색을 포기하며,
		 * peerStream 함수의 반환값이 null로 고정됩니다.(나중에 다시 이 함수로 탐색을 시도해 바꿀 수 있습니다.)</p>
		 * <p>tryInterval 인수는 탐색을 시도하는 간격을 설정합니다.</p>
		 * <p>찾는 데 성공한 경우엔 GogduNetStatusEvent.STATUS 이벤트(dataType:DataType.STATUS, dataDefinition:"GogduNet.Peer.FoundPeerStream")가
		 * 발생하고, 실패한 경우엔 GogduNetStatusEvent.STATUS 이벤트(dataType:DataType.STATUS, dataDefinition:"GogduNet.Peer.FoundPeerStreamFailed")
		 * 가 발생합니다.</p>
		 */
		public function searchForPeerStream(findStream:NetStream, tryNum:int=100, tryInterval:Number=100):void
		{
			if(tryNum < 0 || !_netStream)
			{
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, "GogduNet.Peer.FindPeerStreamFailed", null));
				return;
			}
			
			var i:int;
			var stream:NetStream;
			
			for(i = 0; i < findStream.peerStreams.length; i += 1)
			{
				if(!findStream.peerStreams[i])
				{
					continue;
				}
				
				if(findStream.peerStreams[i].farID == peerID)
				{
					stream = findStream.peerStreams[i];
					break;
				}
			}
			
			if(stream)
			{
				_peerStream = stream;
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, _netStream.farID, DataType.STATUS, "GogduNet.Peer.FoundPeerStream", stream));
				return;
			}
			else
			{
				setTimeout(searchForPeerStream, tryInterval, findStream, tryNum-1, tryInterval);
				return;
			}
		}
		
		public function dispose():void
		{
			if(_netStream){_netStream.dispose();}
			_netStream = null;
			if(_netStream){_peerStream.dispose();}
			_peerStream = null;
			_id = null;
			_event = null;
			_parent = null;
		}
	}
}