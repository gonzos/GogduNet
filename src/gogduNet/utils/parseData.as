package gogduNet.utils
{
	/** data 인수로부터 type에 맞는 데이터를 추출한다. **/
	public function parseData(type:String, data:Object):Object
	{
		// type 문자열을 참고하여 알맞은 유형으로 byte를 변환한다.
		switch(type)
		{
			// define
			case "def":
			{
				return null;
			}
			// string
			case "str":
			{
				if( !(data is String) )
				{
					return null;
				}
				return data;
			}
			// array
			case "arr":
			{
				if( !(data is Array) )
				{
					return null;
				}
				return data;
			}
			// integer
			case "int":
			{
				if( !(data is int) && !(data is uint) && !(data is Number) )
				{
					return null;
				}
				return int(data);
			}
			// unsigned integer
			case "uint":
			{
				if( !(data is int) && !(data is uint) && !(data is Number) )
				{
					return null;
				}
				return uint(data);
			}
			// rationals(rational number)
			case "rati":
			{
				if( !(data is int) && !(data is uint) && !(data is Number) )
				{
					return null;
				}
				return Number(data);
			}
			// boolean(true or false)
			case "tf":
			{
				if( !(data is Boolean) )
				{
					return null;
				}
				return data;
			}
			// JSON
			case "json":
			{
				if( !(data is Object) )
				{
					return null;
				}
				return data;
			}
			default:
			{
				return null;
			}
		}
		
		return null;
	}
}
