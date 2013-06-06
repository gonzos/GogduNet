package gogduNet.utils
{
	//import flash.filesystem.File;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	public class RecordConsole
	{
		public static const MAX_LENGTH:int = 1000000000;
		
		private var _record:String;
		private var _garbageRecords:Vector.<String>;
		private var _byteRecords:Vector.<ByteArray>;
		
		public function RecordConsole()
		{
			_record = '';
			addRecord('Start recording.', true);
			_garbageRecords = new Vector.<String>();
			_byteRecords = new Vector.<ByteArray>();
		}
		
		public function dispose():void
		{
			_record = null;
			_garbageRecords = null;
			_byteRecords = null;
		}
		
		public function addRecord(value:String, appendDate:Boolean=false):String
		{
			if(_record.length > MAX_LENGTH)
			{
				_garbageRecords.push(_record);
				_record = "-Automatically cleared record. previous record is in 'garbageRecords'.\n";
			}
			
			var str:String;
			
			if(appendDate == true)
			{
				var date:Date = new Date();
				str =(date.fullYear + '/' + (date.month+1) + '/' + date.date + '/' + date.hours + ':' + date.minutes + ':' + date.seconds) + "(runningTime:" + getTimer() + ") " + value;
			}
			else
			{
				str = value;
			}
			
			_record += '-' + str + '\n';
			return str;
		}
		
		public function addByteRecord(bytes:ByteArray, appendDate:Boolean=false):uint
		{
			var i:uint = _byteRecords.push(bytes);
			addRecord('Bytes are added. that is at byteRecords[index:' + String(i) + '](length:' + _byteRecords.length + ')', appendDate);
			return i;
		}
		
		public function addErrorRecord(error:Error, descript:String, appendDate:Boolean=false):String
		{
			var str:String = addRecord("Error(id:" + String(error.errorID) + ", name:" + error.name + ", message:" + error.message +
										")(toStr:" + error.toString() + ")(descript:" + descript + ")", appendDate);
			return str;
		}
		
		public function clearRecord():void{
			_record ='';
			addRecord('Records are cleared', true);
		}
		
		public function clearGarbageRecords():void{
			addRecord('GarbageRecords are cleared', true);
			_garbageRecords.length =0;
		}
		
		public function clearByteRecords():void{
			addRecord('ByteRecords are clearred', true);
			_byteRecords.length =0;
		}
		
		public function get record():String
		{
			return _record;
		}
		
		public function get garbageRecords():Vector.<String>
		{
			return _garbageRecords;
		}
		
		public function get byteRecords():Vector.<ByteArray>
		{
			return _byteRecords;
		}
		
		//for AIR
		/*public function saveRecord(url:String, addGarbageRecord:Boolean=true, addByteRecord:Boolean=true):void
		{
			var str:String = "[Records]";
			var i:uint;
			
			if(addGarbageRecord == true)
			{
				for(i = 0; i < _garbageRecords.length; i += 1)
				{
					str += _garbageRecords[i];
				}
			}
			
			str += _record;
			str += "\n\n[ByteRecords]"
			
			if(addByteRecord == true)
			{
				for(i = 0; i < _byteRecords.length; i += 1)
				{
					str += "[" + i + "] " + String(_byteRecords[i]);
				}
			}
			
			var file:File = new File(url);
			file.save(str);
		}*/
	}
}