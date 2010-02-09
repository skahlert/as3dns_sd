package de.unknown.dnssd
{
	public interface DNSSDRegistration extends DNSSDService
	{
		function getTXTRecord():DNSRecord;//throws DNSSDException
		function addRecord(flags:uint,rrType:uint,rData:String,ttl:uint):DNSRecord; //throws DNSSDException
	}
}