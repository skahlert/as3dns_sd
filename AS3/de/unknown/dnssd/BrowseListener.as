package de.unknown.dnssd
{
	public interface BrowseListener extends BaseListener
	{
		function serviceFound(browser:DNSSDService,flags:uint,ifIndex:uint,service:DNSSDServiceInstance):void;
		function serviceLost(browser:DNSSDService,flags:uint,ifIndex:uint,service:DNSSDServiceInstance):void;
	}
}