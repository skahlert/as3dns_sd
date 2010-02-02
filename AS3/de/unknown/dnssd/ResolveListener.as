package de.unknown.dnssd
{
	public interface ResolveListener extends BaseListener
	{
		function serviceResolved(resolver:DNSSDService,flags:uint,ifIndex:uint,fullName:String,hostName:String,port:uint,TXTRecord txtRecord):void;
	}
}