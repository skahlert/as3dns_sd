

#include <dns_sd.h>




#include "AS3.h"



#ifdef __GNUC__
#define	_UNUSED	__attribute__ ((unused))
#else
#define	_UNUSED
#endif

enum {
	kInterfaceVersion = 1		// Must match version in .jar file
};

typedef struct OpContext	OpContext;

struct	OpContext
{
	DNSServiceRef	ServiceRef;
	//JNIEnv			*Env;
	AS3_Val			as3_Obj;
	AS3_Val			ClientObj;
	AS3_Val		Callback;
	AS3_Val		Callback2;
};



/*****************************************************************************
 * Functions provided to ActionScript
 ****************************************************************************/



//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSSD_InitLibrary( JNIEnv *pEnv, jclass cls, jint callerVersion)
static AS3_Val InitLibrary( void* data,AS3_Val args)
{
	int callerVersion = 0;
    AS3_ArrayValue( args, "IntType", &callerVersion );

	if ( callerVersion != kInterfaceVersion)
		return AS3_Int(-kDNSServiceErr_Incompatible);

	return AS3_Int(kDNSServiceErr_NoError);
}

static OpContext	*NewContext(AS3_Val owner,const char *callbackName, const char *callbackSig)
// Create and initialize a new OpContext.
{
	OpContext				*pContext = (OpContext*) malloc( sizeof *pContext);
	
	if ( pContext != NULL)
	{
		pContext->ServiceRef=NULL;
		pContext->as3_Obj = owner;	
		pContext->ClientObj = AS3_GetS(owner,"fListener");
		
		pContext->Callback = AS3_GetS(pContext->ClientObj, callbackName);
		pContext->Callback2 = AS3_Null();		// not always used
	}
	
	return pContext;
}

static void			ReportError(AS3_Val target, AS3_Val service, AS3_Val err)//DNSServiceErrorType err)
// Invoke operationFailed() method on target with err.
{
	
	//Muss ich void* pointer angeben, oder in AS3-Ding umwandeln???
	AS3_Val params = AS3_Array("AS3ValType,AS3ValType", service,err);
	AS3_CallS("operationFailed",target,  params);
	AS3_Release(params);
}

static AS3_Val HaltOperation( void* data,AS3_Val args) //AS3_Val pThis)
/* Deallocate the dns_sd service browser and set the Java object's fNativeContext field to 0. */
{
	AS3_Val pThis; 
	AS3_ArrayValue( args, "AS3ValType", pThis );
	
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
	if ( pContext != NULL)
	{
		// MUST clear fNativeContext first, BEFORE calling DNSServiceRefDeallocate()
		
		AS3_SetS(pThis,"fNativeContext",AS3_Null());
		if ( pContext->ServiceRef != NULL)
			DNSServiceRefDeallocate( pContext->ServiceRef);
		
		AS3_Release(pContext->as3_Obj);
		AS3_Release(pContext->ClientObj);
		free( pContext);
	}
	return AS3_Undefined();

}



//Muss an den schluss!!!!
int main() {
 
    AS3_Val hasAutoCallbacksField = AS3_False();
    
	AS3_Val initMethod = AS3_Function( NULL, InitLibrary );
	AS3_Val haltOperationMethod = AS3_Function( NULL, HaltOperation );
	
	// construct an object that holds references to the functions
	AS3_Val result = AS3_Object( "InitLibrary: AS3ValType,hasAutoCallbacks: AS3ValType,HaltOperation", initMethod,hasAutoCallbacksField,haltOperationMethod );
	
	
	// Release
	AS3_Release( initMethod );
    AS3_Release( hasAutoCallbacksField );
	AS3_Release( haltOperationMethod );
	// notify that we initialized -- THIS DOES NOT RETURN!
	AS3_LibInit( result );
	
	// should never get here!
	return 0;
}
