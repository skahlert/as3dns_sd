package de.unknown.dnssd
{
	
	
	public class CNativeImplementation
	{
		import cmodule.as3dns_sd.CLibInit;
		protected static const _lib_init:cmodule.as3dns_sd.CLibInit = new cmodule.as3dns_sd.CLibInit();
		protected static const _lib:* = _lib_init.init();
		
		
		static public function hasAutoCallbacks():int
		{
			return _lib.hasAutoCallbacks;
		}
		
		static public function InitLibrary(callerVersion:int):int
		{
			return _lib.InitLibrary(callerVersion);
		}
		
		static public function HaltOperation(caller:UnknownService):void
		{
			_lib.HaltOperation(caller);
		}
		
		static public function BlockForData(caller:UnknownService):int
		{
			return _lib.BlockForData(caller);
		}
		
		static public function ProcessResults(caller:UnknownService):int
		{
			return _lib.ProcessResults(caller);
		}
		
		static public function CreateBrowser(caller:UnknownService,flags:uint,ifIndex:uint,regType:String,domain:String):int
		{
			return _lib.CreateBrowser(caller,flags,ifIndex,regType,domain);
		}
		
		static public function CreateResolver(caller:UnknownService,flags:uint,ifIndex:uint,regType:String,domain:String):int
		{
			return _lib.CreateResolver(caller,flags,ifIndex,regType,domain);
		}
		
		static public function BeginRegister(caller:UnknownService,ifIndex:uint,flags:uint,serviceName:String,regType:String,domain:String,host:String,port:uint,txtRecord:String):int
		{
			return _lib.BeginRegister(caller,ifIndex,flags,serviceName,regType,domain,host,port,txtRecord);
		}
		
		static public function AddRecord(caller:UnknownService,flags:uint,rrType:uint,rData:String,ttl:uint,destObject:UnknownDNSRecord):int
		{
			return _lib.AddRecord(caller,flags,rrType,rData,ttl,destObject);
		}

		static public function Update(caller:UnknownService,flags:uint,rData:String,ttl:uint):int
		{
			return _lib.Update(caller,flags,rData,ttl);
		}
		
		static public function Remove(caller:UnknownService):int
		{
			return _lib.Remove(caller);
		}
		
		static public function CreateConnection(caller:UnknownService):int
		{
			return _lib.CreateConnection(caller);
		}
		
		static public function RegisterRecord(caller:UnknownService,flags:uint,ifIndex:uint,fullname:String,rrType:uint,rrClass:uint,rData:String,ttl:uint,destObject:UnknownDNSRecord):int
		{
			return _lib.RegisterRecord(caller,flags,ifIndex,fullname,rrType,rrClass,rData,ttl, destObject);
		}
		
		static public function BeginEnum(caller:UnknownService,flags:uint,ifIndex:uint):int
		{
			return _lib.BeginEnum(caller,flags,ifIndex);
		}
		
		static public function ConstructName(caller:UnknownService,serviceName:String,regtype:String,domain:String,fieldName:String):int
		{
			return _lib.ConstructName(caller,serviceName,regtype,domain,fieldName);
		}
		
		static public function ReconfirmRecord(caller:UnknownService,flags:uint,ifIndex:uint,fullName:String,rrtype:uint,rrclass:uint,rdata:String):int
		{
			return _lib.ReconfirmRecord(caller,flags,ifIndex,fullName,rrtype,rrclass,rdata);
		}
		
		
		

	}
}