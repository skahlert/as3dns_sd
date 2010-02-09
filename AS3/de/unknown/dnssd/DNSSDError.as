//complete
package de.unknown.dnssd
{
	public class DNSSDError extends Error
	{
		public static const		NO_ERROR:int            =  0;
   		public static const		UNKNOWN :int            = 65537;
    	public static const		NO_SUCH_NAME:int        = 65538;
    	public static const		NO_MEMORY :int          = 65539;
    	public static const		BAD_PARAM:int           = 65540;
    	public static const		BAD_REFERENCE :int      = 65541;
    	public static const		BAD_STATE:int           = 65542;
    	public static const		BAD_FLAGS :int          = 65543;
    	public static const		UNSUPPORTED :int		= 65544;
    	public static const		NOT_INITIALIZED  :int   = 65545;
    	public static const		NO_CACHE :int           = 65546;
    	public static const		ALREADY_REGISTERED:int  = 65547;
    	public static const		NAME_CONFLICT:int       = 65548;
    	public static const		INVALID :int            = 65549;
    	public static const		FIREWALL :int           = 65550;
    	public static const		INCOMPATIBLE:int        = 65551;
    	public static const		BAD_INTERFACE_INDEX:int = 65552;
    	public static const		REFUSED :int            = 65553;
    	public static const		NOSUCHRECORD :int       = 65554;
    	public static const		NOAUTH :int             = 65555;
    	public static const		NOSUCHKEY :int          = 65556;
    	public static const		NATTRAVERSAL:int        = 65557;
    	public static const		DOUBLENAT :int          = 65558;
    	public static const		BADTIME:int             = 65559;
    	public static const		BADSIG :int             = 65560;
    	public static const		BADKEY :int             = 65561;
    	public static const		TRANSIENT :int          = 65562;
		
		
		public function DNSSDError(message:String="", id:int=0)
		{
			throw new Error("abstact method. Do not call",0);
			return -1;
		}
		/*
		public function getErrorCode():int
		{
			throw new Error("abstact method. Do not call",0);
			return -1;
		}
		*/
	}
}