package de.unknown.dnssd
{
	public class UnknownRecordRegistrar extends UnknownService implements DNSSDRecordRegistrar
	{
		public function UnknownRecordRegistrar()
		{
			super();
		}
		
		override public function stop():void
		{
		}
		
		public function RegisterRecord(flags:uint, ifIndex:uint, fullname:String, rrtype:uint, rrclass:uint, rdata:String, ttl:uint):DNSRecord
		{
			return null;
		}
		
	}
}