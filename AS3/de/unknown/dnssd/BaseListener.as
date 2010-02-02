package de.unknown.dnssd
{
	public interface BaseListener
	{
		function operationFailed(service:DNSSDService,errorCode:uint):void;
	}
}