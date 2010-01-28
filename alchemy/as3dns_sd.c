/* Copyright (c) 2010 Stefan Kahlert, unknown? visual + virtual design GmbH & Co. KG.
 * All rights reserved.
 * 
 * This file is heavily based on the file JNISupport.c, which is distributed in
 * the Bonjour sourcecode by Apple, Inc. See the original Copyright below.
 *
 * Changes in this file have been made to port the Bonjour functionality to AS3
 * via the Alchemy SDK provided by Adobe.
 *
 * The code is, as of yet, far from working and is still in development.
 *
 * For more information contact Stefan Kahlert (kahlert@unknown.de)
 *
 */ 
 
 
 /*
 * Copyright (c) 2004 Apple Computer, Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 

 
 
 This file contains the platform support for DNSSD and related Java classes.
	It is used to shim through to the underlying <dns_sd.h> API.
 */





#ifndef	AUTO_CALLBACKS
#define	AUTO_CALLBACKS	0
#endif

#if !AUTO_CALLBACKS
#ifdef _WIN32
#include <winsock2.h>
#else //_WIN32
#include <sys/types.h>
#include <sys/select.h>
#endif // _WIN32
#endif // AUTO_CALLBACKS

#include <dns_sd.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <winsock2.h>
#include <iphlpapi.h>
//static char	*	if_indextoname( DWORD ifIndex, char * nameBuff);
//static DWORD	if_nametoindex( const char * nameStr );
#define IF_NAMESIZE MAX_ADAPTER_NAME_LENGTH
#else // _WIN32
#include <sys/socket.h>
//#include <net/if.h>
#endif // _WIN32



//#include <syslog.h>

// convenience definition 
#ifdef __GNUC__
#define	_UNUSED	__attribute__ ((unused))
#else
#define	_UNUSED
#endif

#include "AS3.h"

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

static AS3_Val BlockForData( void* data,AS3_Val args)
/* Block until data arrives, or one second passes. Returns 1 if data present, 0 otherwise. */
{
	// BlockForData() not supported with AUTO_CALLBACKS 
#if !AUTO_CALLBACKS
	AS3_Val pThis; 
	AS3_ArrayValue( args, "AS3ValType", pThis );
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
	if ( pContext != NULL)
	{
		fd_set			readFDs; //??
		int				sd = DNSServiceRefSockFD( pContext->ServiceRef);
		struct timeval	timeout = { 1, 0 };
		FD_ZERO( &readFDs);
		FD_SET( sd, &readFDs);
		
		// Q: Why do we poll here?
		// A: Because there's no other thread-safe way to do it.
		// Mac OS X terminates a select() call if you close one of the sockets it's listening on, but Linux does not,
		// and arguably Linux is correct (See <http://www.ussg.iu.edu/hypermail/linux/kernel/0405.1/0418.html>)
		// The problem is that the Mac OS X behaviour assumes that it's okay for one thread to close a socket while
		// some other thread is monitoring that socket in select(), but the difficulty is that there's no general way
		// to make that thread-safe, because there's no atomic way to enter select() and release a lock simultaneously.
		// If we try to do this without holding any lock, then right as we jump to the select() routine,
		// some other thread could stop our operation (thereby closing the socket),
		// and then that thread (or even some third, unrelated thread)
		// could do some other DNS-SD operation (or some other operation that opens a new file descriptor)
		// and then we'd blindly resume our fall into the select() call, now blocking on a file descriptor
		// that may coincidentally have the same numerical value, but is semantically unrelated
		// to the true file descriptor we thought we were blocking on.
		// We can't stop this race condition from happening, but at least if we wake up once a second we can detect
		// when fNativeContext has gone to zero, and thereby discover that we were blocking on the wrong fd.
		
		if (select( sd + 1, &readFDs, (fd_set*) NULL, (fd_set*) NULL, &timeout) == 1) return AS3_Int(1);
	}
#endif // !AUTO_CALLBACKS
	return AS3_Int(0);
}





//Muss an den schluss!!!!
int main() {
 
    AS3_Val hasAutoCallbacksField = AS3_False();
    
	AS3_Val initMethod = AS3_Function( NULL, InitLibrary );
	AS3_Val haltOperationMethod = AS3_Function( NULL, HaltOperation );
	AS3_Val blockForDataMethod = AS3_Function(NULL, BlockForData);
	
	// construct an object that holds references to the functions
	AS3_Val result = AS3_Object( "InitLibrary: AS3ValType,hasAutoCallbacks: AS3ValType,HaltOperation,BlockForData:IntVal ", initMethod,hasAutoCallbacksField,haltOperationMethod,blockForDataMethod );
	
	
	// Release
	AS3_Release( initMethod );
    AS3_Release( hasAutoCallbacksField );
	AS3_Release( haltOperationMethod );
	// notify that we initialized -- THIS DOES NOT RETURN!
	AS3_LibInit( result );
	
	// should never get here!
	return 0;
}
