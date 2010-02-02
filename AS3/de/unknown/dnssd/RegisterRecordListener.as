package de.unknown.dnssd
{
	public interface RegisterRecordListener extends BaseListener
	{
		function recordRegistered(record:DNSRecord,flags:uint):void;
	}
}