package de.unknown.dnssd
{
	public interface BrowseListener extends BaseListener
	{
		function serviceFound(browser:DNSSDService,flags:uint,ifIndex:uint,serviceName:String,regType:String,domain:String):void;
		function serviceLost(browser:DNSSDService,flags:uint,ifIndex:uint,serviceName:String,regType:String,domain:String):void;
	}
}