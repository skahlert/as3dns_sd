package de.unknown.dnssd
{
	public interface DomainListener extends BaseListener
	{
		function domainFound(domainEnum:DNSSDService,flags:uint,ifIndex:uint,domain:String):void;
		function domainLost(domainEnum:DNSSDService,flags:uint,ifIndex:uint,domain:String):void;
	}
}