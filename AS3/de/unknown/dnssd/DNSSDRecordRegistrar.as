package de.unknown.dnssd
{
	public interface DNSSDRecordRegistrar extends DNSSDService
	{
		function RegisterRecord(flags:uint,ifIndex:uint,fullname:String,rrtype:uint,rrclass:uint,rdata:String,ttl:uint):DNSRecord;
	}
}