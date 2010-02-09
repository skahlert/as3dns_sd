//complete
package de.unknown.dnssd
{
	import flash.system.Capabilities;
	//import flash.S
	
	public class DNSSD
	{
		
		public static const MORE_COMING:uint = ( 1 << 0) ;
		public static const DEFAULT:uint = ( 1 << 2 );
		public static const NO_AUTO_RENAME:uint = ( 1 << 3 );
		public static const SHARED:uint = ( 1 << 4 );
		public static const UNIQUE:uint = ( 1 << 5 );
		public static const BROWSE_DOMAINS:uint = ( 1 << 6 );
		public static const REGISTRATION_DOMAINS:uint = ( 1 << 7 );
		public static const MAX_DOMAIN_NAME:uint = 1005;
		public static const ALL_INTERFACES:uint = 0;
		public static const LOCALHOST_ONLY:int = -1;
		
		
		
		protected static var fInstance:DNSSD;
		
		//Set to private to compensate the lack of abstract classes in AS3
		public function DNSSD()
		{
			
		}
		/*
		static function browse(serviceType:String,listener:BrowserListener):DNSSDService
		{
			//return new DNSSDService(serviceType,listener);
		}
		*/
		public static function browse(flags:uint,ifIndex:uint, regType:String, domain:String, listener:BrowseListener):DNSSDService
		{
			return getInstance()._makeBrowser(flags,ifIndex, regType, domain, listener);
		}
		/*
		public static function browse(regType:String, listener:BrowseListener):DNSSDService
		{
			return getInstance()._makeBrowser(flags,ifIndex, regType, domain, listener);
		}
		*/
		public static function browseS(regType:String,listener:BrowseListener):DNSSDService
		{
			return browse(0,0,regType,"",listener);	
		}
		
		public static function resolve(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, listener:ResolveListener):DNSSDService
		{
			return getInstance()._resolve(flags,ifIndex,serviceName, regType, domain, listener);
		}
		
		public static function register(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, host:String,port:uint,txtRecord:TXTRecord,listener:RegisterListener):DNSSDRegistration
		{
			return getInstance()._register(flags,ifIndex,serviceName, regType, domain,host,port,txtRecord, listener);
		}
		
		public static function registerS(serviceName:String, regType:String, host:String,port:uint,listener:RegisterListener):DNSSDRegistration
		{
			return getInstance()._register(0,0,serviceName, regType, null,null,port,null, listener);
		}
		
		public static function createRecordRegistrar(listener: RegisterRecordListener):DNSSDRecordRegistrar
		{
			return getInstance()._createRecordRegistrar(listener);
		}
		
		public static function queryRecord(flags:uint,ifIndex:uint, serviceName:String, rrType:uint,rrclass:uint,listener:QueryListener):DNSSDService
		{
			return getInstance()._queryRecord(flags,ifIndex,serviceName, rrType, rrclass,listener);
		}
		
		public static function enumerateDomains(flags:uint,ifIndex:uint, listener:DomainListener):DNSSDService
		{
			return getInstance()._enumerateDomains(flags,ifIndex,listener);
		}
		
		
		public static function constructFullName(serviceName:String, regType:String, domain:String):String
		{
			return getInstance()._constructFullName(serviceName, regType, domain);
		}
		
		
		public static function reconfirmRecord(flags:uint,ifIndex:uint, fullName:String, rrType:uint,rrclass:uint,rdata:String):void
		{
			getInstance()._reconfirmRecord(flags,ifIndex,fullName, rrType, rrclass,rdata);
		}
		
		public static function getInstance():DNSSD
		{
			if (fInstance==null)
			{
				fInstance=new UnknownDNSSD();
			}
			
			return fInstance;
		}
		
		
		
		
		protected function _makeBrowser(flags:uint,ifIndex:uint, regType:String, domain:String, listener:BrowseListener):DNSSDService
		{
			return null;
		}
		
		protected function _resolve(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, listener:ResolveListener):DNSSDService
		{
			return null;
		}

		protected function _register(flags:uint,ifIndex:uint, serviceName:String, regType:String, domain:String, host:String,port:uint,txtRecord:TXTRecord,listener:RegisterListener):DNSSDRegistration
		{
			return null;
		}
		
		
		protected function _createRecordRegistrar(listener: RegisterRecordListener):DNSSDRecordRegistrar
		{
			return null;
		}
		
		protected function _queryRecord(flags:uint,ifIndex:uint, serviceName:String, rrType:uint,rrclass:uint,listener:QueryListener):DNSSDService
		{
			return null;
		}
		
		protected function _enumerateDomains(flags:uint,ifIndex:uint, listener:DomainListener):DNSSDService
		{
			return null;
		}
		
		
		protected function _constructFullName(serviceName:String, regType:String, domain:String):String
		{	
			return null;
		}
		
		
		protected function _reconfirmRecord(flags:uint,ifIndex:uint, fullName:String, rrType:uint,rrclass:uint,rdata:String):void
		{
		}

	
		
		
		

	}
	
	
	
}