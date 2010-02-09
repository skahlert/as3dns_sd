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

#include <sys/socket.h>

#include <sys/ioctl.h>
//#include <net/if.h>






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
static AS3_Val AS3_Thunk_InitLibrary( void* data,AS3_Val args)
{
	int callerVersion = 0;
    AS3_ArrayValue( args, "IntType", &callerVersion );

	if ( callerVersion != kInterfaceVersion)
		return AS3_Int(abs(kDNSServiceErr_Incompatible));

	return AS3_Int(abs(kDNSServiceErr_NoError));
}

static OpContext	*NewContext(AS3_Val owner,const char *callbackName)
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

static void			ReportError(AS3_Val target, AS3_Val service, DNSServiceErrorType err) //AS3_Val err)
// Invoke operationFailed() method on target with err.
{
	
	//TODO: Convert DNSServiceErrorType to a AS3-Native class...
	AS3_Val error = AS3_Ptr(&err);
	AS3_Val params = AS3_Array("AS3ValType,AS3ValType", service,error);
	AS3_Release(error);
	AS3_CallS("operationFailed",target,  params);
	AS3_Release(params);
}

static AS3_Val AS3_Thunk_HaltOperation( void* data,AS3_Val args) //AS3_Val pThis)
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

static AS3_Val AS3_Thunk_BlockForData( void* data,AS3_Val args)
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


static AS3_Val AS3_Thunk_ProcessResults( void* data,AS3_Val args)
/* Call through to DNSServiceProcessResult() while data remains on socket. */
{
#if !AUTO_CALLBACKS	// ProcessResults() not supported with AUTO_CALLBACKS 
	
	AS3_Val pThis; 
	AS3_ArrayValue( args, "AS3ValType", pThis );
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
	DNSServiceErrorType err = kDNSServiceErr_BadState;
	
	if ( pContext != NULL)
	{
		int				sd = DNSServiceRefSockFD( pContext->ServiceRef);
		fd_set			readFDs;
		struct timeval	zeroTimeout = { 0, 0 };
		
		//pContext->Env = pEnv;
		
		FD_ZERO( &readFDs);
		FD_SET( sd, &readFDs);
		
		err = kDNSServiceErr_NoError;
		if (0 < select(sd + 1, &readFDs, (fd_set*) NULL, (fd_set*) NULL, &zeroTimeout))
		{
			err = DNSServiceProcessResult(pContext->ServiceRef);
			// Use caution here!
			// We cannot touch any data structures associated with this operation!
			// The DNSServiceProcessResult() routine should have invoked our callback,
			// and our callback could have terminated the operation with op.stop();
			// and that means HaltOperation() will have been called, which frees pContext.
			// Basically, from here we just have to get out without touching any stale
			// data structures that could blow up on us! Particularly, any attempt
			// to loop here reading more results from the file descriptor is unsafe.
		}
	}
	return AS3_Int(abs(err));
#endif // AUTO_CALLBACKS
}


static void DNSSD_API	ServiceBrowseReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
										   DNSServiceErrorType errorCode, const char *serviceName, const char *regtype,
										   const char *replyDomain, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	
	//SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
            AS3_Val _serviceName = AS3_String(serviceName);
            AS3_Val _regtype = AS3_String(regtype);
            AS3_Val _replyDomain = AS3_String(replyDomain);
            AS3_Val _flags = AS3_Int(flags);
            AS3_Val _interfaceIndex = AS3_Int(interfaceIndex);
            AS3_Val params = AS3_Array("AS3ValType,IntType ,IntType ,StrType ,StrType ,StrType ",pContext->as3_Obj, _flags,_interfaceIndex,_serviceName,_regtype,_replyDomain);
            AS3_Call(( flags & kDNSServiceFlagsAdd) != 0 ? pContext->Callback : pContext->Callback2,
                       pContext->ClientObj,
                       params);
             AS3_Release(_serviceName);
             AS3_Release(_regtype);
             AS3_Release(_replyDomain);
             AS3_Release(_flags);
             AS3_Release(_interfaceIndex);
		}
		else
			ReportError(  pContext->ClientObj, pContext->as3_Obj , errorCode);
	}
	
	//TeardownCallbackState();
}


//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleBrowser_CreateBrowser( JNIEnv *pEnv, jobject pThis,
//																	   jint flags, jint ifIndex, jstring regType, jstring domain)
static AS3_Val AS3_Thunk_CreateBrowser( void* data,AS3_Val args)
{
	AS3_Val pThis,flags,ifIndex,regType,domain;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StrType,StrType", pThis,flags,ifIndex,regType,domain );
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != NULL)
		pContext = NewContext( pThis, "serviceFound");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		
		pContext->Callback2 = AS3_GetS(pContext->ClientObj, "serviceLost");
		
		
		err = DNSServiceBrowse( &pContext->ServiceRef, AS3_IntValue(flags), AS3_IntValue(ifIndex), AS3_StringValue(regType), AS3_StringValue(domain), ServiceBrowseReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val ptr = AS3_Ptr(pContext);
			AS3_SetS(pThis,"fNativeContext",ptr);
			AS3_Release(ptr);
		}
		
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}


static void DNSSD_API	ServiceResolveReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
											DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget,
											uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	AS3_Val txtObj;
	
	//SetupCallbackState( &pContext->Env);
	AS3_Val dnssd_namespace = AS3_String("de.unknown.dnssd");
	AS3_Val TXTRecord_class = AS3_NSGetS(dnssd_namespace, "TXTRecord");
	AS3_Val txtCtor = AS3_New(TXTRecord_class, NULL); //Params????
	AS3_Release(dnssd_namespace);
	AS3_Release(TXTRecord_class);
	
	
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL && txtCtor != NULL &&
		NULL != ( txtObj = AS3_String((const char *)txtRecord)))
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
			
			
			AS3_Val _port = AS3_Int(port);
            AS3_Val _fullname = AS3_String(fullname);
            AS3_Val _hosttarget = AS3_String(hosttarget);
            AS3_Val _flags = AS3_Int(flags);
            AS3_Val _interfaceIndex = AS3_Int(interfaceIndex); 
			
			AS3_Val params = AS3_Array("AS3ValType,IntType ,IntType ,StrType ,StrType ,StrType ",
									   pContext->as3_Obj,
									   _flags,
									   _interfaceIndex,
									   _fullname,
									   _hosttarget,
									   _port,
									   txtObj);
			
			AS3_Call(pContext->Callback, pContext->ClientObj,params);
			AS3_Release(_port);
			AS3_Release(_fullname);
			AS3_Release(_hosttarget);
			AS3_Release(_flags);
			AS3_Release(_interfaceIndex);
			
			AS3_Release(txtObj);
		}
		else
			ReportError( pContext->ClientObj, pContext->as3_Obj, errorCode);
	}
	
	//TeardownCallbackState();
}

//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleResolver_CreateResolver( JNIEnv *pEnv, jobject pThis,
//																		 jint flags, jint ifIndex, jstring serviceName, jstring regType, jstring domain)
static AS3_Val AS3_Thunk_CreateResolver( void* data,AS3_Val args)
{
	AS3_Val pThis,flags,ifIndex,serviceName,regType,domain;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StrType,StrType,StrType", pThis,flags,ifIndex,regType,serviceName,domain );
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != NULL)
		pContext = NewContext( pThis, "serviceResolved");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		char	*servStr = AS3_StringValue(serviceName);
		char	*regStr = AS3_StringValue(regType);
		char	*domainStr = AS3_StringValue(domain);
		
		err = DNSServiceResolve( &pContext->ServiceRef, AS3_IntValue(flags), AS3_IntValue(ifIndex),
								servStr, regStr, domainStr, ServiceResolveReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val _pContext= AS3_Ptr(pContext);
            AS3_SetS(pThis,"fNativeContext",_pContext);
            AS3_Release(_pContext);
		}
        free(servStr);
        free(regStr);
        free(domainStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}

static void DNSSD_API	ServiceRegisterReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags,
											 DNSServiceErrorType errorCode, const char *serviceName,
											 const char *regType, const char *domain, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	
	//SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
            AS3_Val _flags = AS3_Int(flags);
            AS3_Val _serviceName = AS3_String(serviceName);
            AS3_Val _regtype = AS3_String(regType);
            AS3_Val _domain = AS3_String(domain);
            
            AS3_Val params = AS3_Array("AS3ValType,IntType ,IntType ,StrType ,StrType ,StrType ",pContext->as3_Obj, _flags,_serviceName,_regtype,_domain);
            AS3_Call(pContext->Callback,
                       pContext->ClientObj,
                       params);
             
            
            
            AS3_Release(_domain);
            AS3_Release(_regtype);
            AS3_Release(_serviceName);
            AS3_Release(_flags);
            AS3_Release(params);
		}
		else
			ReportError(pContext->ClientObj, pContext->as3_Obj, errorCode);
	}
	//TeardownCallbackState();
}


//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRegistration_BeginRegister( JNIEnv *pEnv, jobject pThis,
//																			jint ifIndex, jint flags, jstring serviceName, jstring regType,
//																			jstring domain, jstring host, jint port, jbyteArray txtRecord)
static AS3_Val AS3_Thunk_BeginRegister( void* data,AS3_Val args)
{
	
    AS3_Val pThis,ifIndex,flags,serviceName,regType,domain,host,port,txtRecord;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StrType,StrType,StrType,StrType,IntType,StrType", pThis,ifIndex,flags,serviceName,regType,domain,host,port,txtRecord );
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext = (OpContext*) AS3_PtrValue(contextField);
    
    
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	//syslog(LOG_ERR, "BR: contextField %d", contextField);
	
	if ( contextField != NULL)
		pContext = NewContext( pThis, "serviceRegistered");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		char	*servStr = AS3_StringValue(serviceName);
		char	*regStr = AS3_StringValue(regType);
		char	*domainStr = AS3_StringValue(domain);
		char	*hostStr = AS3_StringValue(host);
        char	*txtRecordStr = AS3_StringValue(txtRecord);
		
		//syslog(LOG_ERR, "BR: regStr %s", regStr);
		
		// Since Java ints are defined to be big-endian, we de-canonicalize 'port' from a 
		// big-endian number into a 16-bit pattern here.
		//uint16_t	portBits = port;
		//portBits = ( ((unsigned char*) &portBits)[0] << 8) | ((unsigned char*) &portBits)[1];
		
		//pBytes = txtRecord ? (*pEnv)->GetByteArrayElements( pEnv, txtRecord, NULL) : NULL;
		uint16_t numBytes = txtRecord ? sizeof(txtRecordStr)/sizeof(char) : 0;
		
		err = DNSServiceRegister( &pContext->ServiceRef, AS3_IntValue(flags), AS3_IntValue(ifIndex), servStr, regStr,  
								 domainStr, hostStr, AS3_IntValue(port),
								 numBytes, txtRecordStr, ServiceRegisterReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val context=AS3_Ptr(pContext);
            AS3_Set(contextField, pThis,  context);
            AS3_Release(context);
		}
		
		if ( txtRecordStr != NULL)
			free(txtRecordStr);
		
		free(servStr);
		free(regStr);
		free(domainStr);
		free(hostStr);
        
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}


//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRegistration_AddRecord( JNIEnv *pEnv, jobject pThis,
//																		jint flags, jint rrType, jbyteArray rData, jint ttl, jobject destObj)
static AS3_Val AS3_Thunk_AddRecord( void* data,AS3_Val args)
{
	AS3_Val pThis,flags,rrType,rData,ttl,destObj;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StrType,IntType,AS3ValType", pThis,flags,rrType,rData,ttl,destObj);
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	OpContext	*pContext;
    
    AS3_Val recField = AS3_GetS(pThis,"fRecord");
    
    
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	//jbyte					*pBytes;
	uint16_t                numBytes;
	DNSRecordRef			recRef;
	
	if ( contextField != NULL)
		pContext = (OpContext*) AS3_PtrValue(contextField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return AS3_Int(abs(kDNSServiceErr_BadParam));
	
	char * _rData = AS3_StringValue(rData);
	//pBytes = (*pEnv)->GetByteArrayElements( pEnv, rData, NULL);
	numBytes = _rData ? sizeof(_rData)/sizeof(char) : 0;
	
	err = DNSServiceAddRecord( pContext->ServiceRef, &recRef, AS3_IntValue(flags), AS3_IntValue(rrType), numBytes, _rData, AS3_IntValue(ttl));
	if ( err == kDNSServiceErr_NoError)
	{
		AS3_Val ref=AS3_Ptr(recRef);
        AS3_Set(recField, pThis,  ref);
        AS3_Release(ref);
        //(*pEnv)->SetIntField( pEnv, destObj, recField, (jint) recRef);
	}
	
	if ( _rData != NULL)
		free(_rData);
	
	return AS3_Int(abs(err));
}


//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSRecord_Update( JNIEnv *pEnv, jobject pThis,
//																  jint flags, jbyteArray rData, jint ttl)
static AS3_Val AS3_Thunk_Update( void* data,AS3_Val args)
{
	AS3_Val pThis,flags,rData,ttl;
	AS3_ArrayValue( args, "AS3ValType,IntType,StrType,IntType", pThis,flags,rData,ttl);
	
	AS3_Val ownerField = AS3_GetS(pThis,"fOwner");
	AS3_Val recField = AS3_GetS(pThis,"fRecord");
    

	OpContext				*pContext = NULL;
	
    DNSServiceErrorType		err = kDNSServiceErr_NoError;
	//jbyte					*pBytes;
	uint16_t					numBytes;
	DNSRecordRef			recRef = NULL;
	
	if ( ownerField != NULL)
	{
		//AS3_Val		ownerObj = (*pEnv)->GetObjectField( pEnv, pThis, ownerField);
		//jclass		ownerClass = (*pEnv)->GetObjectClass( pEnv, ownerObj);
		AS3_Val	contextField = AS3_GetS(ownerField,"fNativeContext");
		if ( contextField != NULL)
			pContext = (OpContext*) AS3_PtrValue(contextField);
	}
	if ( recField != NULL)
		recRef = (DNSRecordRef) AS3_PtrValue(recField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return AS3_Int(abs(kDNSServiceErr_BadParam));
	
	char * _rData = AS3_StringValue(rData);
	numBytes = _rData ? sizeof(_rData)/sizeof(char) : 0;
	
	err = DNSServiceUpdateRecord( pContext->ServiceRef, recRef, AS3_IntValue(flags), numBytes, _rData, AS3_IntValue(ttl));
	
	if ( _rData != NULL)
		free(_rData);
	
	return AS3_Int(abs(err));
}



//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSRecord_Remove( JNIEnv *pEnv, jobject pThis)
static AS3_Val AS3_Thunk_Remove( void* data,AS3_Val args)
{
	AS3_Val pThis;
	AS3_ArrayValue( args, "AS3ValType", pThis);
	
	
	AS3_Val ownerField = AS3_GetS(pThis,"fOwner");
	AS3_Val recField = AS3_GetS(pThis,"fRecord");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	DNSRecordRef			recRef = NULL;
	
	if ( ownerField != NULL)
	{
		AS3_Val	contextField = AS3_GetS(ownerField,"fNativeContext");
		if ( contextField != NULL)
			pContext = (OpContext*) AS3_PtrValue(contextField);
	}
	if ( recField != NULL)
		recRef = (DNSRecordRef) AS3_PtrValue(recField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return AS3_Int(abs(kDNSServiceErr_BadParam));
	
	err = DNSServiceRemoveRecord( pContext->ServiceRef, recRef, 0);
	
	return AS3_Int(abs(err));
}


//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRecordRegistrar_CreateConnection( JNIEnv *pEnv, jobject pThis)
static AS3_Val AS3_Thunk_CreateConnection( void* data,AS3_Val args)
{
	AS3_Val pThis;
	AS3_ArrayValue( args, "AS3ValType", pThis);
	
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != NULL)
		pContext = NewContext(pThis, "recordRegistered");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		err = DNSServiceCreateConnection( &pContext->ServiceRef);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val _pContext=AS3_Ptr(pContext);
			AS3_Set(contextField,pThis,_pContext);
			AS3_Release(_pContext);
		}
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}


struct RecordRegistrationRef
{
	OpContext		*Context;
	AS3_Val			RecordObj;
};
typedef struct RecordRegistrationRef	RecordRegistrationRef;



static void DNSSD_API	RegisterRecordReply( DNSServiceRef sdRef _UNUSED, 
											DNSRecordRef recordRef _UNUSED, DNSServiceFlags flags, 
											DNSServiceErrorType errorCode, void *context)

{
	RecordRegistrationRef	*regEnvelope = (RecordRegistrationRef*) context;
	OpContext		*pContext = regEnvelope->Context;
	
	//SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{	
		if ( errorCode == kDNSServiceErr_NoError)
		{	
			AS3_Val _flags = AS3_Int(flags);
            
            
            AS3_Val params = AS3_Array("AS3ValType,IntType",regEnvelope->RecordObj, _flags);
            AS3_Call(pContext->Callback,
					 pContext->ClientObj,
					 params);
			
            AS3_Release(_flags);
            
		}
		else
			ReportError( pContext->ClientObj, pContext->as3_Obj, errorCode);
	}
	AS3_Release(regEnvelope->RecordObj);
	
	free( regEnvelope);
	
	//TeardownCallbackState();
}




//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRecordRegistrar_RegisterRecord( JNIEnv *pEnv, jobject pThis, 
//																				jint flags, jint ifIndex, jstring fullname, jint rrType, jint rrClass, 
//																				jbyteArray rData, jint ttl, jobject destObj)
static AS3_Val AS3_Thunk_RegisterRecord( void* data,AS3_Val args)
{
	
	AS3_Val pThis,flags,ifIndex,fullname,rrType,rrClass,rData,ttl, destObj;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StringType,IntType,IntType,StringType,IntType,AS3ValType", pThis,flags,ifIndex,fullname,rrType,rrClass,rData,ttl, destObj);
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	AS3_Val recField = AS3_GetS(destObj,"fRecord");
	OpContext				*pContext = NULL;
	
	
	char				*nameStr = AS3_StringValue(fullname);

	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	//jbyte					*pBytes;
	uint16_t				numBytes;
	DNSRecordRef			recRef;
	RecordRegistrationRef	*regEnvelope;
	
	if ( contextField != NULL)
		pContext = (OpContext*) AS3_PtrValue(contextField);
	if ( pContext == NULL || pContext->ServiceRef == NULL || nameStr == NULL)
		return AS3_Int(abs(kDNSServiceErr_BadParam));
	
	regEnvelope = calloc( 1, sizeof *regEnvelope);
	if ( regEnvelope == NULL)
		return AS3_Int(abs(kDNSServiceErr_NoMemory));
	regEnvelope->Context = pContext;
	regEnvelope->RecordObj = destObj;
	
	char * _rData = AS3_StringValue(rData);
	numBytes = _rData ? sizeof(_rData)/sizeof(char) : 0;

	
	err = DNSServiceRegisterRecord( pContext->ServiceRef, &recRef, AS3_IntValue(flags), AS3_IntValue(ifIndex), 
								   nameStr, AS3_IntValue(rrType), AS3_IntValue(rrClass), numBytes, _rData, AS3_IntValue(ttl),
								   RegisterRecordReply, regEnvelope);
	
	if ( err == kDNSServiceErr_NoError)
	{
		AS3_Val _recRef= AS3_Ptr(recRef);
		AS3_Set(recField,destObj,_recRef);
		AS3_Release(_recRef);
	}
	else
	{
		if ( regEnvelope->RecordObj != NULL)
			AS3_Release(regEnvelope->RecordObj);
		free( regEnvelope);
	}
	
	if ( _rData != NULL)
		free(_rData);
	
	free(nameStr);
	
	return AS3_Int(abs(err));
}

static void DNSSD_API	ServiceQueryReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
										  DNSServiceErrorType errorCode, const char *serviceName,
										  uint16_t rrtype, uint16_t rrclass, uint16_t rdlen,
										  const void *rdata, uint32_t ttl, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	//char *			rDataArr;
	AS3_Val			_rdata;
	
	//SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)// &&	NULL != ( rDataArr = char[rdlen])))
	{	
		if ( errorCode == kDNSServiceErr_NoError)
		{
			
			//TODO: Keine ahnung, ob das funktioniert  !!!!!!!!!!!!!!!
			//memcpy( rDataArr, rdata, rdlen);
			_rdata = AS3_String((char*)rdata);
			//(*pContext->Env)->ReleaseByteArrayElements( pContext->Env, rDataObj, pBytes, JNI_COMMIT);
			
			AS3_Val _flags = AS3_Int(flags);
            AS3_Val _interfaceIndex = AS3_Int(interfaceIndex);
			AS3_Val _serviceName = AS3_String(serviceName);
			AS3_Val _rrtype = AS3_Int(rrtype);
			AS3_Val _rrclass = AS3_Int(rrclass);
			AS3_Val _ttl = AS3_Int(ttl);
			
            
            AS3_Val params = AS3_Array("AS3ValType,IntType,IntType,StringType,IntType,IntType,AS3ValType,IntType",pContext->as3_Obj, _flags,_interfaceIndex,_serviceName,_rrtype,_rrclass,_rdata,_ttl);
            AS3_Call(pContext->Callback,
					 pContext->ClientObj,
					 params);
			
            AS3_Release(_flags);
			AS3_Release(_interfaceIndex);
			AS3_Release(_serviceName);
			AS3_Release(_rrtype);
			AS3_Release(_rrclass);
			AS3_Release(_ttl);
			AS3_Release(_rdata);
	
		}
		else
			ReportError(pContext->ClientObj, pContext->as3_Obj, errorCode);
	}
	//TeardownCallbackState();
}



//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleQuery_CreateQuery( JNIEnv *pEnv, jobject pThis,
//																   jint flags, jint ifIndex, jstring serviceName, jint rrtype, jint rrclass)
static AS3_Val AS3_Thunk_CreateQuery( void* data,AS3_Val args)
{
	
	AS3_Val pThis,flags,ifIndex,serviceName,rrtype,rrclass;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StringType,IntType,IntType", pThis,flags,ifIndex,serviceName,rrtype,rrclass);
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");

	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != NULL)
		pContext = NewContext(pThis, "queryAnswered");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		char	*servStr = AS3_StringValue(serviceName);
		err = DNSServiceQueryRecord( &pContext->ServiceRef, AS3_IntValue(flags), AS3_IntValue(ifIndex), servStr,
									AS3_IntValue(rrtype), AS3_IntValue(rrclass), ServiceQueryReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val _pContext = AS3_Ptr(pContext);
			AS3_Set(contextField, pThis,_pContext);
		}
		
		free(servStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}



static void DNSSD_API	DomainEnumReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
										DNSServiceErrorType errorCode, const char *replyDomain, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	
	//SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
			
			AS3_Val _flags = AS3_Int(flags);
            AS3_Val _interfaceIndex = AS3_Int(interfaceIndex);
			AS3_Val _replyDomain = AS3_String(replyDomain);

            
            AS3_Val params = AS3_Array("AS3ValType,IntType,IntType,StrType",pContext->as3_Obj, _flags,_interfaceIndex,_replyDomain);
            AS3_Call(( flags & kDNSServiceFlagsAdd) != 0 ? pContext->Callback : pContext->Callback2,
					 pContext->ClientObj,
					 params);
			
            AS3_Release(_flags);
			AS3_Release(_interfaceIndex);
			AS3_Release(_replyDomain);
		}
		else
			ReportError( pContext->ClientObj, pContext->as3_Obj, errorCode);
	}
	//TeardownCallbackState();
}



//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDomainEnum_BeginEnum( JNIEnv *pEnv, jobject pThis,
//																	  jint flags, jint ifIndex)
static AS3_Val AS3_Thunk_BeginEnum( void* data,AS3_Val args)
{
	AS3_Val pThis,flags,ifIndex;
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType", pThis,flags,ifIndex);
	AS3_Val contextField = AS3_GetS(pThis,"fNativeContext");
	
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != NULL)
		pContext = NewContext(pThis, "domainFound");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		
		pContext->Callback2 = AS3_GetS(pContext->ClientObj,"domainLost");
		
		err = DNSServiceEnumerateDomains( &pContext->ServiceRef, AS3_IntValue(flags), AS3_IntValue(ifIndex),
										 DomainEnumReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			AS3_Val _pContext = AS3_Ptr(pContext);
			AS3_Set(pThis,contextField,_pContext);
			AS3_Release(_pContext);
		}
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return AS3_Int(abs(err));
}

/* TODO: Need Workaround for this method!!! */

//JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSSD_ConstructName( JNIEnv *pEnv, jobject pThis _UNUSED,
//																	 jstring serviceName, jstring regtype, jstring domain, jobjectArray pOut)
static AS3_Val AS3_Thunk_ConstructName( void* data,AS3_Val args)
{
	
	AS3_Val pThis,serviceName,regtype,domain;
	char *fieldName;
	AS3_ArrayValue( args, "AS3ValType,StrType,StrType,StrType,StrType",pThis,serviceName,regtype,domain,fieldName);
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	char				*nameStr = AS3_StringValue(serviceName);
	char				*regStr = AS3_StringValue(regtype);
	char				*domStr = AS3_StringValue(domain);
	char					buff[ kDNSServiceMaxDomainName + 1];
	
	err = DNSServiceConstructFullName( buff, nameStr, regStr, domStr);
	
	if ( err == kDNSServiceErr_NoError)
	{
		
		
		
		// pOut is expected to be a String[1] array.s
		AS3_Val arrToSend = AS3_Array("StrValue",buff);
		
		
		AS3_SetS(pThis,fieldName,arrToSend);
		
		//might crash Terribly!!!
		//memcpy(pOut,arrToCopy,sizeof(arrToCopy));
		AS3_Release(arrToSend);
	}
	
	free(nameStr);
	free(regStr);
	free(domStr);
				 
	free(fieldName);
	
	return AS3_Int(abs(err));
}


//JNIEXPORT void JNICALL Java_com_apple_dnssd_AppleDNSSD_ReconfirmRecord( JNIEnv *pEnv, jobject pThis _UNUSED,
//																	   jint flags, jint ifIndex, jstring fullName,
//																	   jint rrtype, jint rrclass, jbyteArray rdata)
static AS3_Val AS3_Thunk_ReconfirmRecord( void* data,AS3_Val args)
{
	AS3_Val pThis;
	
	int flags,ifIndex,rrtype,rrclass;
	char * fullName,*rdata;
	
	AS3_ArrayValue( args, "AS3ValType,IntType,IntType,StrType,IntType,IntType,StrType",pThis,&flags,&ifIndex,fullName,&rrtype,&rrclass,rdata);

	uint32_t					numBytes;
	
	//pBytes = (*pEnv)->GetByteArrayElements( pEnv, rdata, NULL);
	numBytes = rdata ? sizeof(rdata)/sizeof(char) : 0;
	
	DNSServiceReconfirmRecord( flags, ifIndex, fullName, rrtype, rrclass, numBytes, rdata);
	
	
	
	free(fullName);
	free(rdata);
	
	return AS3_Null();
}



/*
 Probably not possible in avm2 sandbox?
 
 
 JNIEXPORT jstring JNICALL Java_com_apple_dnssd_AppleDNSSD_GetNameForIfIndex( JNIEnv *pEnv, jobject pThis _UNUSED,
 jint ifIndex)
 {
 char					*p = LOCAL_ONLY_NAME, nameBuff[IF_NAMESIZE];
 
 if (ifIndex != (jint) kDNSServiceInterfaceIndexLocalOnly)
 p = if_indextoname( ifIndex, nameBuff );
 
 return (*pEnv)->NewStringUTF( pEnv, p);
 }
 
 
 JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSSD_GetIfIndexForName( JNIEnv *pEnv, jobject pThis _UNUSED,
 jstring ifName)
 {
 uint32_t				ifIndex = kDNSServiceInterfaceIndexLocalOnly;
 const char				*nameStr = SafeGetUTFChars( pEnv, ifName);
 
 if (strcmp(nameStr, LOCAL_ONLY_NAME))
 ifIndex = if_nametoindex( nameStr);
 
 SafeReleaseUTFChars( pEnv, ifName, nameStr);
 
 return ifIndex;
 }
 
 */




int main() {
 
    AS3_Val hasAutoCallbacksField = AS3_True();
	AS3_Val initMethod = AS3_Function( NULL, AS3_Thunk_InitLibrary );
	AS3_Val haltOperationMethod = AS3_Function( NULL, AS3_Thunk_HaltOperation );
	AS3_Val blockForDataMethod = AS3_Function(NULL, AS3_Thunk_BlockForData);
	AS3_Val processResultsMethod = AS3_Function(NULL, AS3_Thunk_ProcessResults);
	AS3_Val createBrowserMethod = AS3_Function(NULL, AS3_Thunk_CreateBrowser);
	AS3_Val beginRegisterMethod = AS3_Function(NULL, AS3_Thunk_BeginRegister); 
	AS3_Val addRecordMethod = AS3_Function(NULL, AS3_Thunk_AddRecord);
	AS3_Val updateMethod = AS3_Function(NULL, AS3_Thunk_Update); 
	AS3_Val removeMethod = AS3_Function(NULL, AS3_Thunk_Remove);
	AS3_Val createConnectionMethod = AS3_Function(NULL, AS3_Thunk_CreateConnection);
	AS3_Val createResolverMethod = AS3_Function(NULL, AS3_Thunk_CreateResolver);
	AS3_Val registerRecordMethod = AS3_Function(NULL, AS3_Thunk_RegisterRecord);
	AS3_Val createQuery = AS3_Function(NULL, AS3_Thunk_CreateQuery);
	AS3_Val beginEnumMethod = AS3_Function(NULL, AS3_Thunk_BeginEnum);
	AS3_Val constructNameMethod = AS3_Function(NULL, AS3_Thunk_ConstructName);
	AS3_Val reconfirmRecordMethod = AS3_Function(NULL, AS3_Thunk_ReconfirmRecord);

	
	AS3_Val result = AS3_Object( "hasAutoCallbacks: IntType",hasAutoCallbacksField);
	AS3_SetS( result,"InitLibrary",initMethod);
	AS3_SetS( result,"HaltOperation",haltOperationMethod);
	AS3_SetS( result,"BlockForData",blockForDataMethod);
	AS3_SetS( result,"ProcessResults",processResultsMethod);
	AS3_SetS( result,"CreateBrowser",createBrowserMethod);
	AS3_SetS( result,"BeginRegister",beginRegisterMethod);
	AS3_SetS( result,"AddRecord",addRecordMethod);
	AS3_SetS( result,"Update",updateMethod);
	AS3_SetS( result,"Remove",removeMethod);
	AS3_SetS( result,"CreateConnection",createConnectionMethod);
	AS3_SetS( result,"CreateResolver",createResolverMethod);
	AS3_SetS( result,"RegisterRecord",registerRecordMethod);
	AS3_SetS( result,"CreateQuery",createQuery);
	AS3_SetS( result,"BeginEnum",beginEnumMethod);
	
	AS3_SetS( result,"ConstructName",constructNameMethod);
	AS3_SetS( result,"ReconfirmRecord",reconfirmRecordMethod);
	
	
	// Release
	AS3_Release( initMethod );
    AS3_Release( hasAutoCallbacksField );
	AS3_Release( haltOperationMethod );
	AS3_Release( blockForDataMethod );
	AS3_Release( processResultsMethod );
	AS3_Release( createBrowserMethod );
	AS3_Release( beginRegisterMethod );
	AS3_Release( addRecordMethod );
	AS3_Release( updateMethod );
	AS3_Release( removeMethod );
	AS3_Release( createConnectionMethod );
	AS3_Release( createResolverMethod );
	AS3_Release( registerRecordMethod );
	AS3_Release( createQuery );
	AS3_Release( beginEnumMethod );
	AS3_Release( constructNameMethod );
	AS3_Release( reconfirmRecordMethod );
	
	
	// notify that we initialized -- THIS DOES NOT RETURN!
	AS3_LibInit( result );
	
	// should never get here!
	return 0;
}
