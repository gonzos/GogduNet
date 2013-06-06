package gogduNet.sockets
{
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.NetStream;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import gogduNet.utils.ObjectPool;
	import gogduNet.utils.RandomID;
	
	import gogduNet.events.GogduNetStatusEvent;
	import gogduNet.sockets.DataType;
	import gogduNet.sockets.GogduNetPeer;
	import gogduNet.utils.RecordConsole;
	import gogduNet.utils.makePacket;
	import gogduNet.utils.parsePacket;
	
	/** 상태 변화나 작업 보고 등, 다용도 이벤트 */
	[Event(name="status", type="gogduNet.events.GogduNetStatusEvent")]
	/** 정상적인 데이터를 수신했을 때 발생. 데이터는 가공되어 이벤트로 전달된다. */
	[Event(name="receiveData", type="gogduNet.events.GogduNetStatusEvent")]
	/** 정상적이지 않은 데이터를 수신했을 때 발생 */
	[Event(name="invalidPacket", type="gogduNet.events.GogduNetStatusEvent")]
	
	/** <strong>기본적인 사용법(GogduNetP2PClient)</strong>
	 * <p><code>
	 * var client:GogduNetP2PClient = new GogduNetP2PClient("127.0.0.1", "testRoom");</br>
	 * client.connect();</br>
	 * client.addEventListener(GogduNetStatusEvent.STATUS, connected);</br>
	 * </br>
	 * function connected(e:GogduNetStatusEvent):void</br>
	 * {</br>
	 * 　if(e.dataType == DataType.STATUS)</br>
	 * 　{</br>
	 * 　　if(e.dataDefinition == "GogduNet.Connect.Success")</br>
	 * 　　{</br>
	 * 　　　trace("connected");</br>
	 * 　　}</br>
	 * 　}</br>
	 * }</code></p>
	 * 
	 * @langversion 3.0
	 * @playerversion Flash Player 11
	 * @playerversion AIR 3.0
	 */
	public class GogduNetP2PClient extends EventDispatcher
	{
		/** 최대 연결 지연 한계 **/
		private var _connectionDelayLimit:Number;
		/** 연결 검사용 타이머 */
		private var _timer:Timer;
		
		/** 패킷을 추출할 때 사용할 정규 표현식 */
		private	var _reg:RegExp = /(?!\.)[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]+\./g;
		/** 필요 없는 패킷들을 제거할 때 사용할 정규 표현식 */
		private var _reg2:RegExp = /[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/=]*[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\+\/\.=]+[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstupvxyz0123456789\+\/=]*|(?<=\.)\.+|(?<!.)\./g;
		
		private var _url:String;
		private var _netGroupName:String;
		private var _maxConnections:uint;
		private var _groupSpecifier:GroupSpecifier;
		private var _netConnection:NetConnection;
		private var _netGroup:NetGroup;
		private var _netStream:NetStream;
		
		/** 현재 연결되어 있는가를 나타내는 bool 값 */
		private var _isConnected:Boolean;
		/** 연결된 지점의 시간을 나타내는 변수 */
		private var _connectedTime:Number;
		/** 마지막으로 통신한 시각(정확히는 마지막으로 정보를 전송 받은 시각) */
		private var _lastReceivedTime:Number;
		/** 디버그용 기록 */
		private var _record:RecordConsole;
		
		/** peer들을 저장해 두는 배열 */
		private var _peerArray:Vector.<GogduNetPeer>;
		/** peer의 peer id를 주소값으로 사용하여 저장하는 객체 */
		private var _peerTable:Object;
		/** peer 객체의 id(not peerID)를 주소값으로 사용하여 저장하는 객체 */
		private var _idTable:Object;
		
		private var _randomID:RandomID;
		
		private var _event:GogduNetStatusEvent;
		
		private var _peerPool:ObjectPool;
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체 */
		private var _connectionSecurity:GogduNetConnectionSecurity;
		
		/** <p>url : 접속할 주소(rtmfp)</p>
		 * <p>name : NetGroup 이름</p>
		 * <p>maxConnections : flash.net.NetConnection.maxPeerConnections 속성을 설정한다.
		 * <p>connectionSecurity : 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체. 값이 null인 경우 자동으로 생성(new GogduNetConnectionSecurity(false))</p>
		 * <p>timerInterval : 타이머 간격(GogduNetP2PClient의 timer는 정보 수신을 겸하지 않고 오로지 연결 검사용으로만 쓰이기 때문에 반복 속도(timerInterval)가 조금
		 * 느려도 괜찮습니다. 밀리초 단위)</p>
		 * <p>connectionDelayLimit : 연결 지연 한계(여기서 설정한 시간 동안 특정 피어로부터 데이터가 오지 않으면 그 피어와 연결이 끊긴 것으로 간주한다. 초 단위)</p>
		 */
		public function GogduNetP2PClient(url:String, netGroupName:String="GogduNet", maxConnections:uint=8, connectionSecurity:GogduNetConnectionSecurity=null, timerInterval:Number=1000, connectionDelayLimit:Number=10)
		{
			_connectionDelayLimit = connectionDelayLimit;
			_timer = new Timer(timerInterval);
			_url = url;
			_netGroupName = netGroupName;
			
			_groupSpecifier = new GroupSpecifier(_netGroupName);
			_groupSpecifier.postingEnabled = true;
			_groupSpecifier.serverChannelEnabled = true;
			_netConnection = new NetConnection();
			_netConnection.maxPeerConnections = maxConnections;
			
			_isConnected = false;
			_connectedTime = -1;
			
			_record = new RecordConsole();
			_peerArray = new Vector.<GogduNetPeer>();
			_peerTable = new Object();
			_idTable = new Object();
			_event = new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, "GogduNet.ConnectionUpdated", null);
			
			_randomID = new RandomID();
			_peerPool = new ObjectPool(GogduNetPeer);
			
			if(connectionSecurity == null)
			{
				connectionSecurity = new GogduNetConnectionSecurity(false);
			}
			_connectionSecurity = connectionSecurity;
		}
		
		/** 연결할 url 값을 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get url():String
		{
			return _url;
		}
		public function set url(value:String):void
		{
			if(_isConnected == true)
			{
				return;
			}
			
			_url = value;
		}
		
		/** 연결할 넷 그룹의 이름을 가져오거나 설정한다. 설정은 연결하고 있지 않을 때에만 할 수 있다. */
		public function get netGroupName():String
		{
			return _netGroupName;
		}
		public function set netGroupName(value:String):void
		{
			if(_isConnected == true)
			{
				return;
			}
			
			_netGroupName = value;
		}
		
		/** flash.net.NetConnection.maxPeerConnections 속성을 가져오거나 설정한다. (이 값은 새로 들어오는 연결에만 영향을 주며, 기존 연결은 끊어지지 않는다.)*/
		public function get maxConnections():uint
		{
			return _netConnection.maxPeerConnections;
		}
		public function set maxConnections(value:uint):void
		{
			_netConnection.maxPeerConnections = value;
		}
		
		/** 통신이 허용 또는 비허용된 목록을 가지고 있는 GogduNetConnectionSecurity 타입 객체를 가져오거나 설정한다. (GogduNetP2PClient에서만 특수하게, GogduNetConnectionSecurity 객체에 추가할 Object 객체의 address 속성을 peerID로, port 속성을 음수로 설정해야 합니다.) */
		public function get connectionSecurity():GogduNetConnectionSecurity
		{
			return _connectionSecurity;
		}
		public function set connectionSecurity(value:GogduNetConnectionSecurity):void
		{
			_connectionSecurity = value;
		}
		
		/** 연결 검사용 타이머의 재생 간격을 가져온다. */
		public function get timerInterval():Number
		{
			return _timer.delay;
		}
		/** 연결 검사용 타이머의 재생 간격을 설정한다. */
		public function set timerInterval(value:Number):void
		{
			_timer.delay = value;
		}
		
		/** 연결 지연 한계를 가져온다.(초 단위) */
		public function get connectionDelayLimit():Number
		{
			return _connectionDelayLimit;
		}
		/** 연결 지연 한계를 설정한다.(초 단위) */
		public function set connectionDelayLimit(value:Number):void
		{
			_connectionDelayLimit = value;
		}
		
		/** 연결되어 있는 peer의 수를 가져온다.('모든' peer가 아니라 '나와 연결된' peer의 수. 즉, 나 자신을 제외한 수) */
		public function get connectedPeers():uint
		{
			return _peerArray.length;
		}
		
		/** 나 자신의 peer id를 가져온다. */
		public function get peerID():String
		{
			/*if(_isConnected == false)
			{
				return;
			}*/
			
			return _netConnection.nearID;
		}
		
		public function get isConnected():Boolean
		{
			return _isConnected;
		}
		
		public function get record():RecordConsole
		{
			return _record;
		}
		
		/** 각 피어에게 id를 발급해 주는 RandomID 타입의 객체를 가져온다. */
		public function get idIssuer():RandomID
		{
			return _randomID;
		}
		
		public function get peerPool():ObjectPool
		{
			return _peerPool;
		}
		
		/** 연결된 후 시간이 얼마나 지났는지를 나타내는 Number 값을 가져온다.(초 단위) */
		public function get elapsedTimeAfterConnected():Number
		{
			if(_isConnected == false)
			{
				return -1;
			}
			
			return getTimer() / 1000.0 - _connectedTime;
		}
		
		/** 마지막으로 연결된 시각으로부터 지난 시간을 가져온다.(초 단위) */
		public function get elapsedTimeAfterLastReceived():Number
		{
			return getTimer() / 1000.0 - _lastReceivedTime;
		}
		
		/** 마지막으로 연결된 시각을 갱신한다.
		 * (정보가 들어온 경우 자동으로 이 함수가 실행되어 갱신된다.)
		 */
		private function updateLastReceivedTime():void
		{
			_lastReceivedTime = getTimer() / 1000.0;
			dispatchEvent(_event);
		}
		
		public function connect():void
		{
			if(!_url || _isConnected == true)
			{
				return;
			}
			
			_netConnection.addEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
			_netConnection.connect(_url);
		}
		
		public function close():void
		{
			if(_isConnected == false)
			{
				return;
			}
			
			var i:int;
			var peer:GogduNetPeer;
			
			for(i = 0; i < _peerArray.length; i += 1)
			{
				if(!_peerArray[i])
				{
					continue;
				}
				
				peer = _peerArray[i];
				
				peer.removeEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
				_idTable[peer.id] = null;
				peer.netStream.close();
				peer.dispose();
			}
			
			_peerArray.length = 0;
			_peerTable = {};
			_idTable = {};
			_randomID.clear();
			_peerPool.clear();
			
			_netStream.close();
			_netGroup.close();
			_netGroup.removeEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
			_netConnection.close();
			_netConnection.removeEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
			_netConnection = new NetConnection(); //NetConnection is non reusable after NetConnection.close()
			_timer.stop();
			_timer.removeEventListener(TimerEvent.TIMER, _timerFunc);
			
			_record.addRecord("Connection to close(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")", true);
			_isConnected = false;
		}
		
		public function dispose():void
		{
			close();
			
			_timer = null;
			_reg = null;
			_reg2 = null;
			_url = null;
			_netGroupName = null;
			_groupSpecifier = null;
			_netConnection = null;
			_netGroup = null;
			if(_netStream){_netStream.dispose();}
			_netStream = null;
			_record.dispose();
			_record = null;
			_peerArray = null;
			_peerTable = null;
			_idTable = null;
			_event = null;
			_randomID.dispose();
			_randomID = null;
			_peerPool.dispose();
			_peerPool = null;
			_connectionSecurity.dispose();
			_connectionSecurity = null;
			
			_isConnected = false;
		}
		
		/** peer id로 peer를 가져온다. */
		public function getPeerByPeerID(targetPeerID:String):GogduNetPeer
		{
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer)
			{
				return _peerTable[targetPeerID];
			}
			else
			{
				return null;
			}
			
			return null;
		}
		
		/** 식별용 id로 peer를 가져온다. */
		public function getPeerByID(id:String):GogduNetPeer
		{
			if(_idTable[id] && _idTable[id] is GogduNetPeer)
			{
				return _idTable[id];
			}
			else
			{
				return null;
			}
			
			return null;
		}
		
		/** 모든 peer를 가져온다. 반환되는 배열은 복사된 값이므로 수정하더라도 내부에 있는 원본 배열은 바뀌지 않는다. */
		public function getPeers(resultVector:Vector.<GogduNetPeer>=null):Vector.<GogduNetPeer>
		{
			if(resultVector == null)
			{
				resultVector = new Vector.<GogduNetPeer>();
			}
			
			var i:uint;
			var peer:GogduNetPeer;
			
			for(i = 0; i < _peerArray.length; i += 1)
			{
				if(_peerArray[i] == null)
				{
					continue;
				}
				peer =_peerArray[i];
				
				resultVector.push(peer);
			}
			
			return resultVector;
		}
		
		/** 해당 peerID의 전송용 스트림을 가져온다. */
		public function getPeerStream(targetPeerID:String):NetStream
		{
			var i:int;
			var peerStream:NetStream;
			
			for(i = 0; i < _netStream.peerStreams.length; i += 1)
			{
				if(!_netStream.peerStreams[i])
				{
					continue;
				}
				
				peerStream = _netStream.peerStreams[i];
				
				if(peerStream.farID == targetPeerID)
				{
					return peerStream;
				}
			}
			
			return null;
		}
		
		public function sendDefinition(definition:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.DEFINITION, definition);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendString(definition:String, data:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.STRING, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendArray(definition:String, data:Array):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.ARRAY, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendInteger(definition:String, data:int):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendUnsignedInteger(definition:String, data:uint):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.UNSIGNED_INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendRationals(definition:String, data:Number):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.RATIONALS, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendBoolean(definition:String, data:Boolean):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.BOOLEAN, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		/** this data's type is Object or String**/
		public function sendJSON(definition:String, data:Object):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			if(data is String)
			{
				try
				{
					data = JSON.parse(String(data));
				}
				catch(e:Error)
				{
					return false;
				}
			}
			
			var str:String = makePacket(DataType.JSON, definition, data);
			if(str == null)
			{
				return false;
			}
			
			_netStream.send("sendData", str);
			return true;
		}
		
		public function sendDefinitionTo(targetPeerID:String, definition:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.DEFINITION, definition);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendStringTo(targetPeerID:String, definition:String, data:String):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.STRING, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendArrayTo(targetPeerID:String, definition:String, data:Array):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.ARRAY, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendIntegerTo(targetPeerID:String, definition:String, data:int):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendUnsignedIntegerTo(targetPeerID:String, definition:String, data:uint):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.UNSIGNED_INTEGER, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendRationalsTo(targetPeerID:String, definition:String, data:Number):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.RATIONALS, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendBooleanTo(targetPeerID:String, definition:String, data:Boolean):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			var str:String = makePacket(DataType.BOOLEAN, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		public function sendJSONTo(targetPeerID:String, definition:String, data:Boolean):Boolean
		{
			if(_isConnected == false)
			{
				return false;
			}
			
			if(data is String)
			{
				try
				{
					data = JSON.parse(String(data));
				}
				catch(e:Error)
				{
					return false;
				}
			}
			
			var str:String = makePacket(DataType.JSON, definition, data);
			if(str == null)
			{
				return false;
			}
			
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer && _peerTable[targetPeerID].peerStream)
			{
				_peerTable[targetPeerID].peerStream.send("sendData", str);
				return true;
			}
			else
			{
				return false;
			}
			
			return false;
		}
		
		/** GogduNet.Neighbor.Connect이나 GogduNet.Connect.Success이 발생한 직후는 연결이 불안정하여 데이터가 제대로 전달되지 않습니다.
		 * 반드시 연결이 안정된 후에 데이터를 전송하세요. */
		private function _onNetStatus(e:NetStatusEvent):void
		{
			var info:Object = e.info;
			var code:String = info.code;
			var peer:GogduNetPeer;
			
			if(info.level == DataType.ERROR)
			{
				// 연결에 실패한 경우
				if(code == "NetConnection.Connect.Failed" || code == "NetGroup.Connect.Failed")
				{
					_record.addRecord("ConnectFailed(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(code:" + code + ")", true);
					_isConnected = true; //close 함수의 if(_isConnected == false){return;} 때문에
					close();
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, "GogduNet.Connect.Failed", null));
					return;
				}
				// 연결이 끊긴 경우
				else if(code == "NetConnection.Connect.AppShutdown" || code == "NetConnection.Connect.InvalidApp" || 
					code == "NetConnection.Connect.Rejected")
				{
					_record.addRecord("Disconnected(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(code:" + code + ")", true);
					close();
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, "GogduNet.Disconnect", code));
					return;
				}
				else
				{
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, code, e));
					return;
				}
			}
			
			else if(info.level == DataType.STATUS)
			{
				if(code == "NetConnection.Connect.IdleTimeout")
				{
					close();
					_record.addRecord("Disconnected(code:" + code + ")", true);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.ERROR, "GogduNet.Disconnect", code));
				}
				else if(code == "NetConnection.Connect.Success")
				{
					//NetGroup is non reusable after NetGroup.close()
					_netGroup = new NetGroup(_netConnection, _groupSpecifier.groupspecWithAuthorizations());
					_netStream = new NetStream(_netConnection, NetStream.DIRECT_CONNECTIONS);
					_netStream.client = {onPeerConnect:_onPeerConnect};
					_netStream.publish(_netGroupName);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
					return;
				}
				// 연결에 성공한 경우
				else if(code == "NetGroup.Connect.Success")
				{
					_connectedTime = getTimer() / 1000.0;
					updateLastReceivedTime();
					
					_netGroup.addEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
					_timer.start();
					_timer.addEventListener(TimerEvent.TIMER, _timerFunc);
					
					_isConnected = true;
					_record.addRecord("Connected(connectedTime:" + _connectedTime + ")", true);
					
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, "GogduNet.Connect.Success", null));
					return;
				}
				//NetGroup에 누군가가 접속한 경우
				else if(code == "NetGroup.Neighbor.Connect")
				{
					updateLastReceivedTime();
					
					var bool:Boolean = false;
					
					if(_connectionSecurity.isPermission == true)
					{
						if(_connectionSecurity.contain(info.peerID, -1) == true)
						{
							bool = true;
						}
					}
					else if(_connectionSecurity.isPermission == false)
					{
						if(_connectionSecurity.contain(info.peerID, -1) == false)
						{
							bool = true;
						}
					}
					
					if(bool == false)
					{
						_record.addRecord("Sensed unpermitted connection(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(peerID:" + info.peerID + ")", true);
						dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, info.peerID, null, "GogduNet.UnpermittedConnection"));
						return;
					}
					
					//피어를 배열에 추가하고 추가된 위치(index)를 가져와 그걸로 피어 객체를 찾는다.
					peer = _peerArray[_addPeer(info.peerID)];
					//해당 피어와의 연결을 갱신
					peer.updateLastReceivedTime();
					
					_record.addRecord("Neighbor connected(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + peer.id + ", peerID:" + info.peerID + ")", true);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, info.peerID, DataType.STATUS, "GogduNet.Neighbor.Connect", null));
				}
				//NetGroup에서 누군가가 나간 경우
				else if(code == "NetGroup.Neighbor.Disconnect")
				{
					peer = getPeerByPeerID(info.peerID);
					
					if(peer != null)
					{
						_record.addRecord("Neighbor disconnected(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + peer.id + ", peerID:" + info.peerID + ")", true);
					}
					else
					{
						_record.addRecord("Neighbor disconnected(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:[null], peerID:" + info.peerID + ")", true);
					}
					
					_removePeer(info.peerID);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, info.peerID, DataType.STATUS, "GogduNet.Neighbor.Disconnect", null));
				}
				else
				{
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, null, DataType.STATUS, code, e));
				}
			}
		}
		
		private function _onPeerConnect(ns:NetStream):void
		{
			updateLastReceivedTime();
			
			var bool:Boolean = false;
			
			if(_connectionSecurity.isPermission == true)
			{
				if(_connectionSecurity.contain(ns.farID, -1) == true)
				{
					bool = true;
				}
			}
			else if(_connectionSecurity.isPermission == false)
			{
				if(_connectionSecurity.contain(ns.farID, -1) == false)
				{
					bool = true;
				}
			}
			
			if(bool == false)
			{
				_record.addRecord("Sensed unpermitted connection(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(peerID:" + ns.farID + ")", true);
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, ns.farID, null, "GogduNet.UnpermittedConnection"));
				ns.close();
				return;
			}
			
			_peerArray[_addPeer(ns.farID)].updateLastReceivedTime();
		}
		
		/** peer를 배열에 저장해 둔다. */
		private function _addPeer(targetPeerID:String):uint
		{
			var i:int;
			for(i = 0; i < _peerArray.length; i += 1)
			{
				if(!_peerArray[i])
				{
					continue;
				}
				
				// 이미 배열에 이 peer가 존재하고 있는 경우
				if(_peerArray[i].peerID == targetPeerID)
				{
					return i;
				}
			}
			
			var ns:NetStream = new NetStream(_netConnection, targetPeerID);
			ns.addEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
			
			var peer:GogduNetPeer = _peerPool.getInstance() as GogduNetPeer;
			peer.initialize();
			peer.setNetStream(ns);
			peer.setID(_randomID.getID());
			peer.searchForPeerStream(_netStream);
			peer._setParent(this);
			
			ns.client = {sendData:peer._getData};
			ns.play(_netGroupName);
			
			_idTable[peer.id] = peer;
			_peerTable[targetPeerID] = peer;
			return _peerArray.push(peer)-1;
		}
		
		/** 배열에 있는 peer를 제거한다. */
		private function _removePeer(targetPeerID:String):void
		{
			var peer:GogduNetPeer = getPeerByPeerID(targetPeerID);
			
			if(peer == null)
			{
				return;
			}
			
			_idTable[peer.id] = null;
			_peerArray.splice( _peerArray.indexOf(peer), 1 );
			_peerTable[targetPeerID] = null;
			peer.netStream.close();
			peer.dispose();
			_peerPool.returnInstance(peer);
		}
		
		/** 타이머로 반복되는 함수 */
		private function _timerFunc(e:TimerEvent):void
		{
			_checkConnect();
		}
		
		/** 연결 상태를 검사 */
		private function _checkConnect():void
		{
			var peer:GogduNetPeer;
			
			for each(peer in _peerArray)
			{
				if(peer == null)
				{
					continue;
				}
				
				// 일정 시간 이상 전송이 오지 않을 경우 접속이 끊긴 것으로 간주하여 이쪽에서도 접속을 끊는다.
				if(peer.elapsedTimeAfterLastReceived > _connectionDelayLimit)
				{
					_record.addRecord("Close connection to peer(NoResponding)(id:" + peer.id + ", peerID:" + peer.peerID + ")", true);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.STATUS, false, false, peer.peerID, DataType.STATUS, "GogduNet.Neighbor.Disconnect.NoResponding", null));
					_removePeer(peer.peerID);
					continue;
				}
			}
		}
		
		internal function _getData(targetPeerID:String, jsonStr:String):void
		{
			updateLastReceivedTime();
			if(_peerTable[targetPeerID] && _peerTable[targetPeerID] is GogduNetPeer)
			{
				var peer:GogduNetPeer = _peerTable[targetPeerID];
				peer.updateLastReceivedTime();
			}
			
			var backupStr:String = jsonStr;
			
			// 필요 없는 잉여 패킷(잘못 전달되었거나 악성 패킷)이 있으면 제거한다.
			if(_reg2.test(jsonStr) == true)
			{
				_record.addRecord("Sensed surplus packets(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + 
						peer.id + ", peerID:" + targetPeerID + ")(str:" + backupStr + ")", true);
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.INVALID_PACKET, false, false, targetPeerID, null, "GogduNet.InvalidPacket.Surplus", backupStr));
				jsonStr.replace(_reg2, "");
			}
			
			// 필요한 패킷을 추출한다.
			var regArr:Array = jsonStr.match(_reg);
			
			// 만약 패킷이 없거나 1개보다 많을 경우
			if(regArr.length == 0 || regArr.length > 1)
			{
				_record.addRecord("Sensed wrong packets(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + 
						peer.id + ", peerID:" + targetPeerID + ")(str:" + backupStr + ")", true);
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.INVALID_PACKET, false, false, targetPeerID, null, "GogduNet.InvalidPacket.Wrong", backupStr));
				return;
			}
			
			// 패킷에 오류가 있는지를 검사합니다.
			var obj:Object = parsePacket(regArr[0]);
			
			// 패킷에 오류가 있으면
			if(obj == null)
			{
				_record.addRecord("Sensed wrong packets(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + 
						peer.id + ", peerID:" + targetPeerID + ")(str:" + regArr[0] + ")", true);
				dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.INVALID_PACKET, false, false, targetPeerID, null, "GogduNet.InvalidPacket.Wrong", regArr[0]));
				return;
			}
			// 패킷에 오류가 없으면
			else
			{
				if(obj.t == DataType.DEFINITION)
				{
					_record.addRecord("Data received(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + 
						peer.id + ", peerID:" + targetPeerID + ")"/*(type:" + obj.type + ", def:" + 
							obj.def + ")"*/, true);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.RECEIVE_DATA, false, false, targetPeerID, obj.t, obj.df, null));
				}
				else
				{
					_record.addRecord("Data received(elapsedTimeAfterConnected:" + elapsedTimeAfterConnected + ")(id:" + 
						peer.id + ", peerID:" + targetPeerID + ")"/*(type:" + obj.type + ", def:" + 
							obj.def + ", data:" + obj.data ")"*/, true);
					dispatchEvent(new GogduNetStatusEvent(GogduNetStatusEvent.RECEIVE_DATA, false, false, targetPeerID, obj.t, obj.df, obj.dt));
				}
			}
		}
	}
}