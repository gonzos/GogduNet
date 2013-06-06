package gogduNet.sockets
{
	public class GogduNetConnectionSecurity
	{
		private var _isPermission:Boolean;
		//{address, port}
		private var _connections:Vector.<Object>;
		
		/** (GogduNetP2PClient에서만 특수하게, 객체에 추가할 Object 객체의 address 속성을 peerID로, port 속성을 음수로 설정해야 합니다.) */
		public function GogduNetConnectionSecurity(isPermission:Boolean, connections:Vector.<Object>=null)
		{
			_isPermission = isPermission;
			
			if(connections == null)
			{
				connections = new Vector.<Object>();
			}
			_connections = connections;
		}
		
		public function get isPermission():Boolean
		{
			return _isPermission;
		}
		public function set isPermission(value:Boolean):void
		{
			_isPermission = value;
		}
		
		/** {address, port} address가 null이면 port만 일치해도 허용/비허용 대상, port가 음수면 address만 일치해도 허용/비허용 대상. 그러나 둘 다(address가 null이고 port가 음수)는 할 수 없다. */
		public function get connections():Vector.<Object>
		{
			return _connections;
		}
		public function set connections(value:Vector.<Object>):void
		{
			_connections = value;
		}
		
		public function addConnection(address:String, port:int):void
		{
			var i:int;
			for(i = 0; i < _connections.length; i += 1)
			{
				if(_connections[i])
				{
					if(_connections[i].address == address && _connections[i].port == port)
					{
						return;
					}
				}
			}
			
			_connections.push({address:address, port:port});
		}
		
		public function removeConnection(address:String, port:int):void
		{
			var i:int;
			for(i = 0; i < _connections.length; i += 1)
			{
				if(_connections[i])
				{
					if(_connections[i].address == address && _connections[i].port == port)
					{
						_connections.splice(i, 1);
					}
				}
			}
		}
		
		public function clear():void
		{
			_connections.length = 0;
		}
		
		public function contain(address:String, port:int):Boolean
		{
			var i:int;
			for(i = 0; i < _connections.length; i += 1)
			{
				if(_connections[i])
				{
					if(!_connections[i].address || _connections[i].address == address)
					{
						if(_connections[i].port < 0 && _connections[i].port == port)
						{
							return true;
						}
					}
				}
			}
			
			return false;
		}
		
		public function dispose():void
		{
			_connections = null;
		}
	}
}