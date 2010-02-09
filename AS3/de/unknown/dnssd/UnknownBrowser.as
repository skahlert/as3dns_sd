//complete
package de.unknown.dnssd
{
	
	import flash.events.*;
	
	public class UnknownBrowser extends UnknownService
	{
		public function UnknownBrowser(flags:uint, ifIndex:uint, regType:String, domain:String,  client:BrowseListener) 
		{
			super(client);
			this.ThrowOnErr(this.CreateBrowser(flags,ifIndex,regType,domain));
			addEventListener(Event.RENDER,run);
		}
		
		protected function CreateBrowser(flags:uint,ifIndex:uint,regType:String,domain:String):int
		{
			return CNativeImplementation.CreateBrowser(this,flags,ifIndex,regType,domain);
		}
		
	}
}