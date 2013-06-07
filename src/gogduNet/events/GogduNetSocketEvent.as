package gogduNet.events
{
	import flash.events.Event;
	import flash.net.Socket;
	
	import gogduNet.sockets.GogduNetSocket;
	
	/** <strong>GogduNetSocketEvent.UNPERMITTED_CONNECTION</strong></br>
	 * 허용되지 않은 연결 시도가 감지된 경우에 발생한다.(GogduNetServer)</br></br>
	 * 
	 * <strong>GogduNetSocketEvent.CONNECT</strong></br>
	 * 소켓이 접속에 성공한 경우에 발생한다.(GogduNetServer)</br></br>
	 * 
	 * <strong>GogduNetSocketEvent.CONNECT_FAILED</strong></br>
	 * 소켓이 접속을 시도했으나 실패한 경우에 발생한다. (GogduNetServer)</br>
	 * 	<ul>GogduNetSocketEvent.info ==
	 * 		<li>GogduNetSocketEvent.INFO_SATURATION : 서버의 인원 수 제한에 의해 연결이 거부된 경우에 발생한다. (nativeSocket:접속을 시도했던 flash.net.Socket 객체)</li>
	 * 	</ul>
	 * </br>
	 * <strong>GogduNetSocketEvent.CLOSE</strong></br>
	 * 소켓의 연결이 끊긴 경우에 발생한다.
	 * 	<ul>GogduNetSocketEvent.info ==
	 * 		<li>GogduNetSocketEvent.INFO_NORMAL_CLOSE : 정상적인 연결 끊김(서버에서 연결을 끊은 것이 아닌, 클라이언트의 자발적인 끊음)</li>
	 * 		<li>GogduNetSocketEvent.INFO_ABNORMAL_CLOSE : 정상적이지 않은 끊김. 응답이 없어 끊긴 경우(GogduNetServer.connectionDelayLimit 시간 동안 소켓으로부터의 데이터 전송이 없는 경우)</li>
	 * 	</ul>
	 */
	public class GogduNetSocketEvent extends Event
	{
		public static const UNPERMITTED_CONNECTION:String = "unpermittedConnection";
		
		public static const CONNECT:String = "connect";
		public static const CONNECT_FAILED:String = "connectFailed";
		public static const CLOSE:String = "close";
		
		public static const CONNECTION_UPDATED:String = "connectionUpdated";
		
		// info string
		//public static const INFO_INVALID_IP:String = "gogduNet.GogduNetSocketEvent.InfoInvalidIP";
		public static const INFO_IO_ERROR:String = "infoIOError";
		public static const INFO_SECURITY_ERROR:String = "infoSecurityError";
		public static const INFO_SATURATION:String = "infoSaturation";
		public static const INFO_NORMAL_CLOSE:String = "infoNormalClose";
		public static const INFO_ABNORMAL_CLOSE:String = "infoAbnormalClose";
		
		private var _socket:GogduNetSocket;
		private var _nativeSocket:Socket;
		private var _info:String;
		
		public function GogduNetSocketEvent(eventType:String, bubbles:Boolean=false, cancelable:Boolean=false,
											socket:GogduNetSocket=null, nativeSocket:Socket=null, info:String=null)
		{
			super(eventType, bubbles, cancelable);
			_socket = socket;
			_nativeSocket = nativeSocket;
			_info = info;
		}
		
		public function get socket():GogduNetSocket
		{
			return _socket;
		}
		
		public function get nativeSocket():Socket
		{
			return _nativeSocket;
		}
		
		public function get info():String
		{
			return _info;
		}
		
		override public function clone():Event
		{
			return new GogduNetSocketEvent(type, bubbles, cancelable, _socket, _nativeSocket, _info);
		}
	}
}