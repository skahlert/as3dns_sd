//completed
package de.unknown.dnssd
{
	public class UnknownResolver extends UnknownService
	{
		
		import flash.events.*;
		
		public function UnknownResolver(flags:uint, ifIndex:uint, serviceName:String,domain:String,client: ResolveListener)
		{
			super(client);
			this.ThrowOnErr(this.CreateResolver(flags,ifIndex,serviceName,domain));
			addEventListener(Event.RENDER,run);
		}
		
		public function CreateResolver(flags:uint,ifIndex:uint,serviceName:String,domain:String):int
		{
			return CNativeImplementation.CreateResolver(this,flags,ifIndex,serviceName,domain);
		}
		
		
	}
}