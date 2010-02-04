package de.unknown.dnssd
{
	import flash.filesystem.File;
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
		protected  static function getInstance():DNSSD 
		{
			return fInstance;
		}
		
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
		
		
		protected function _makeBrowser(flags:uint,ifIndex:uint, regType:String, domain:String, listener:BrowseListener)
		{
		}

		

	}
	
}