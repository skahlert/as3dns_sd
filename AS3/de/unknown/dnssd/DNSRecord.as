package de.unknown.dnssd
{
	public interface DNSRecord
	{
		function update(flags:uint,rData:String,ttl:uint):void;
		function remove():void;
	}
}