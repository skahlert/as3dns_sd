package de.unknown.dnssd
{
	public interface RegisterListener extends BaseListener
	{
		function serviceRegistered(registration:DNSSDService,flags:uint,serviceName:String,regType:String,domain:String):void;
	}
}