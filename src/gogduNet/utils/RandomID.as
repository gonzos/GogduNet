package gogduNet.utils
{
	import flash.utils.getTimer;
	
	/**
	 * @author : Siyania
	 * @create : May 26, 2013
	 */
	public class RandomID
	{
		private var _container:Object;
		
		/** getID() 함수를 통해 고유한 id 문자열을 생성한다. returnID()로 사용한 id를 반납할 수 있으며, clear() 함수로 모든 기록을 지울 수도 있다. */
		public function RandomID()
		{
			_container = new Object();
		}
		
		/** 중복 판별을 위해 사용되는 기록을 가져온다. */
		public function get history():Object
		{
			return _container;
		}
		
		/** 중복 판별을 위해 사용되는 기록을 모두 지운다. 기록을 지운 후 생성한 id는, 기록을 지우기 전에 생성한 id와 중복될 수도 있다. */
		public function clear():void
		{
			_container = new Object();
		}
		
		/** 중복되지 않는 고유한 문자열을 생성한다. */
		public function getID():String
		{
			var str:String = _getRandomNum();
			var bool:Boolean = true;
			
			while(bool)
			{
				if(!_container[str])
				{
					_container[str] = true;
					bool = false;
				}
				else
				{
					str = _getRandomNum();
					continue;
				}
			}
			
			return str;
		}
		
		private function _getRandomNum():String
		{
			var num:uint = uint(Math.random() * uint.MAX_VALUE);
			/*var dateTime:Number = new Date().time;*/
			var currTime:int = getTimer();
			return String(num) /*+ "." + String(dateTime)*/ + "." + String(currTime);
		}
		
		/** 사용한 문자열을 반납한다. 반납한 후엔, 반납했던 문자열과 같은 문자열이 getID() 함수로 생성될 수도 있다. */
		public function returnID(id:String):void
		{
			if(_container[id])
			{
				_container[id] = null;
			}
		}
		
		public function dispose():void
		{
			_container = null;
		}
	}
}