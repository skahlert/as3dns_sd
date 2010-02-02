package de.unknown.bonjour
{
	import flash.filesystem.File;
	import flash.system.Capabilities;
	//import flash.S
	
	public class DNSSD
	{
		
		public static const MORE_COMING:uint = 1;
		public static const ADD:uint = 2; 
		
		
		//Set to private to compensate the lack of abstract classes in AS3
		protected function DNSSD()
		{
		}
		
		public static function browse(serviceType:String,listener:BrowserListener):DNSSDService
		{
			//return new DNSSDService(serviceType,listener);
		}
		
		

	}
}