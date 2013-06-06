package gogduNet.utils
{
	import flash.utils.ByteArray;
	import flash.utils.CompressionAlgorithm;
	
	//import com.hurlant.crypto.symmetric.XTeaKey;
	//import com.hurlant.util.Hex;
	
	public class Encryptor
	{
		//public static var cipher:XTeaKey = new XTeaKey(Hex.toArray("809849497DF33CE3809849497DF33CE3809849497DF33CE3809849497DF33CE3809849497DF33CE3"));
		
		/** 문자열을 압축+암호화하여 반환합니다. */
        public static function encode(str:String):String
		{
			var bytes:ByteArray = new ByteArray();
			bytes.writeUTFBytes(str);
			
			bytes.compress(CompressionAlgorithm.DEFLATE);
			//cipher.encrypt(bytes); //암호화
			//bytes.compress(CompressionAlgorithm.DEFLATE);
			
			return Base64.encode(bytes);
		}
		
		/** encode 함수로 압축+암호화한 문자열을 다시 원래대로 되돌립니다. */
        public static function decode(str:String):String
		{
			var bytes:ByteArray = Base64.decode(str);
			
			bytes.uncompress(CompressionAlgorithm.DEFLATE);
			//cipher.decrypt(bytes); //복호화
			//bytes.uncompress(CompressionAlgorithm.DEFLATE);
			
			return bytes.readUTFBytes(bytes.length);
		}
	}
}