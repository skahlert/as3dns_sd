package de.unknown.dnssd
{
	
	public class UnknownDNSSD extends DNSSD
	{
		
		public static var hasAutoCallbacks:Boolean; //Should normally be set automatically by InitLibrary()
		
		public function UnknownDNSSD()
		{
			var libInitResult:int=CNativeImplementation.InitLibrary(1);
			if ( libInitResult != DNSSDError.NO_ERROR)
				throw new UnknownDNSSDError(libInitResult);
		}
		
		
		override protected function _makeBrowser(flags:uint,ifIndex:uint, regType:String,domain:String,client:BrowseListener):DNSSDService
		{
			return new UnknownBrowser(flags,ifIndex,regType,domain,client);
		}
		
		
		
		override protected function _resolve(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, listener:ResolveListener):DNSSDService
		{
			return new UnknownResolver(flags,ifIndex,serviceName,domain,listener);
		}

		override protected function _register(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, host:String,port:uint,txtRecord:TXTRecord,listener:RegisterListener):DNSSDRegistration
		{
			return new UnknownRegistration(flags,ifIndex,serviceName,regType,domain,host,port,txtRecord,listener);
		}
		
		
		override protected function _createRecordRegistrar(listener: RegisterRecordListener):DNSSDRecordRegistrar
		{
			return new UnknownRecordRegistrar(listener);
		}
		
		override protected function _queryRecord(flags:uint,ifIndex:uint, serviceName:String, rrType:uint,rrclass:uint,listener:QueryListener):DNSSDService
		{
			return new UnknownQuery(flags,ifIndex,serviceName,rrType,rrclass,listener);
		}
		
		override protected function _enumerateDomains(flags:uint,ifIndex:uint, listener:DomainListener):DNSSDService
		{
			return new UnknownDomainEnum(flags,ifIndex,listener);
		}
		
		
		override protected function _constructFullName(serviceName:String, regType:String, domain:String):String
		{	
			//TODO: Find out how to work around the direct memory access problem!!!
			return null;
		}
		
		
		override protected function _reconfirmRecord(flags:uint,ifIndex:uint, fullName:String, rrType:uint,rrclass:uint,rdata:String):void
		{
			CNativeImplementation.ReconfirmRecord(this,flags,ifIndex,fullName,rrType,rrclass,rdata);
		}
		
	}
	
}