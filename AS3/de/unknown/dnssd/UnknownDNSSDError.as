//complete
package de.unknown.dnssd
{
	public class UnknownDNSSDError extends DNSSDError
	{
		protected var fErrorCode:int;
		
		public function UnknownDNSSDError(errorCode:int=0)
		{
			fErrorCode = errorCode;
			var message:String="UNKNOWN";
			var kMessages:Array = new Array(		// should probably be put into a resource or something
			"UNKNOWN",
			"NO_SUCH_NAME",
			"NO_MEMORY",
			"BAD_PARAM",
			"BAD_REFERENCE",
			"BAD_STATE",
			"BAD_FLAGS",
			"UNSUPPORTED",
			"NOT_INITIALIZED",
			"NO_CACHE",
			"ALREADY_REGISTERED",
			"NAME_CONFLICT",
			"INVALID",
			"FIREWALL",
			"INCOMPATIBLE",
			"BAD_INTERFACE_INDEX",
			"REFUSED",
			"NOSUCHRECORD",
			"NOAUTH",
			"NOSUCHKEY",
			"NATTRAVERSAL",
			"DOUBLENAT",
			"BADTIME",
			"BADSIG",
			"BADKEY",
			"TRANSIENT"
			);
			
			if ( fErrorCode >= UNKNOWN && fErrorCode < ( UNKNOWN - kMessages.length))
			{
				message= "DNS-SD Error " + fErrorCode + ": " + kMessages[ UNKNOWN - fErrorCode];
			}
			
			super(message, errorCode);
		}
		
		//public function getErrorCode():int{return fErrorCode};
		
		
		
		
	}
}