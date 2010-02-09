package de.unknown.dnssd
{
	public class UnknownRegistration extends UnknownService implements DNSSDRegistration
	{
		public function UnknownRegistration()
		{
			super();
		}
		
		override public function stop():void
		{
		}
		
		public function getTXTRecord():DNSRecord
		{
			return null;
		}
		
		public function addRecord(flags:uint, rrType:uint, rData:String, ttl:uint):DNSRecord
		{
			return null;
		}
		
	}
}