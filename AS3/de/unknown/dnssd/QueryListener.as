package de.unknown.dnssd
{
	public interface QueryListener extends BaseListener
	{
		function queryAnswered(query:DNSSDService,flags:uint,ifIndex:uint,fullName:String,rrType:uint,rrClass:uint,rData:String,ttl:uint):void;
	}
}