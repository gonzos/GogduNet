package gogduNet.sockets
{
	public class DataType
	{
		/** ERROR와 STATUS은 GogduNetP2PClient와 그와 관련된 P2P 클래스에서만 쓰이는 형식이다. */
		public static const ERROR:String = "error";
		public static const STATUS:String = "status";
		
		public static const DEFINITION:String = "def";
		public static const STRING:String = "str";
		public static const ARRAY:String = "arr";
		public static const INTEGER:String = "int";
		public static const UNSIGNED_INTEGER:String = "uint";
		public static const RATIONALS:String = "rati";
		public static const BOOLEAN:String = "tf";
		public static const JSON:String = "json";
		
		public function DataType()
		{
			throw new Error("DataType 클래스는 인스턴스 객체를 생성할 수 없습니다.");
		}
	}
}