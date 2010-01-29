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
	AS3_Val tmp = AS3_Number(-1.0);
	AS3_Trace(AS3_Number(1.0));
	AS3_Trace(AS3_Number(1000.0));
	AS3_Trace(tmp);
	AS3_Trace(AS3_Number(-1.0));
	
	if ( callerVersion != kInterfaceVersion)
	{	
		tmp= AS3_Int(kDNSServiceErr_Incompatible);
		//return AS3_Number((double)kDNSServiceErr_Incompatible);
	}else {
		tmp= AS3_Int(0);
	}
	AS3_Trace(tmp);
	return tmp;
	
	//return AS3_String("test2");
}




/* TODO:
 * Methods of the original to yet implement (or discard)
 *
 *
 *





#if AUTO_CALLBACKS
static void	SetupCallbackState( JNIEnv **ppEnv)
{
	(*gJavaVM)->AttachCurrentThread( gJavaVM, (void**) ppEnv, NULL);
}

static void	TeardownCallbackState( void )
{
	(*gJavaVM)->DetachCurrentThread( gJavaVM);
}

#else	// AUTO_CALLBACKS

static void	SetupCallbackState( JNIEnv **ppEnv _UNUSED)
{
	// No setup necessary if ProcessResults() has been called
}

static void	TeardownCallbackState( void )
{
	// No teardown necessary if ProcessResults() has been called
}
#endif	// AUTO_CALLBACKS

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleBrowser_CreateBrowser( JNIEnv *pEnv, jobject pThis,
																	   jint flags, jint ifIndex, jstring regType, jstring domain)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "serviceFound",
							  "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		const char	*regStr = SafeGetUTFChars( pEnv, regType);
		const char	*domainStr = SafeGetUTFChars( pEnv, domain);
		
		pContext->Callback2 = (*pEnv)->GetMethodID( pEnv,
												   (*pEnv)->GetObjectClass( pEnv, pContext->ClientObj),
												   "serviceLost", "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
		
		err = DNSServiceBrowse( &pContext->ServiceRef, flags, ifIndex, regStr, domainStr, ServiceBrowseReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
		
		SafeReleaseUTFChars( pEnv, regType, regStr);
		SafeReleaseUTFChars( pEnv, domain, domainStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}


static void DNSSD_API	ServiceResolveReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
											DNSServiceErrorType errorCode, const char *fullname, const char *hosttarget,
											uint16_t port, uint16_t txtLen, const unsigned char *txtRecord, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	jclass			txtCls;
	jmethodID		txtCtor;
	jbyteArray		txtBytes;
	jobject			txtObj;
	jbyte			*pBytes;
	
	SetupCallbackState( &pContext->Env);
	
	txtCls = (*pContext->Env)->FindClass( pContext->Env, "com/apple/dnssd/TXTRecord");
	txtCtor = (*pContext->Env)->GetMethodID( pContext->Env, txtCls, "<init>", "([B)V");
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL && txtCtor != NULL &&
		NULL != ( txtBytes = (*pContext->Env)->NewByteArray( pContext->Env, txtLen)))
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
			// Since Java ints are defined to be big-endian, we canonicalize 'port' from a 16-bit
			// pattern into a number here.
			port = ( ((unsigned char*) &port)[0] << 8) | ((unsigned char*) &port)[1];
			
			// Initialize txtBytes with contents of txtRecord
			pBytes = (*pContext->Env)->GetByteArrayElements( pContext->Env, txtBytes, NULL);
			memcpy( pBytes, txtRecord, txtLen);
			(*pContext->Env)->ReleaseByteArrayElements( pContext->Env, txtBytes, pBytes, JNI_COMMIT);
			
			// Construct txtObj with txtBytes
			txtObj = (*pContext->Env)->NewObject( pContext->Env, txtCls, txtCtor, txtBytes);
			(*pContext->Env)->DeleteLocalRef( pContext->Env, txtBytes);
			
			(*pContext->Env)->CallVoidMethod( pContext->Env, pContext->ClientObj, pContext->Callback,
											 pContext->JavaObj, flags, interfaceIndex,
											 (*pContext->Env)->NewStringUTF( pContext->Env, fullname),
											 (*pContext->Env)->NewStringUTF( pContext->Env, hosttarget),
											 port, txtObj);
		}
		else
			ReportError( pContext->Env, pContext->ClientObj, pContext->JavaObj, errorCode);
	}
	
	TeardownCallbackState();
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleResolver_CreateResolver( JNIEnv *pEnv, jobject pThis,
																		 jint flags, jint ifIndex, jstring serviceName, jstring regType, jstring domain)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "serviceResolved",
							  "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;Ljava/lang/String;ILcom/apple/dnssd/TXTRecord;)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		const char	*servStr = SafeGetUTFChars( pEnv, serviceName);
		const char	*regStr = SafeGetUTFChars( pEnv, regType);
		const char	*domainStr = SafeGetUTFChars( pEnv, domain);
		
		err = DNSServiceResolve( &pContext->ServiceRef, flags, ifIndex,
								servStr, regStr, domainStr, ServiceResolveReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
		
		SafeReleaseUTFChars( pEnv, serviceName, servStr);
		SafeReleaseUTFChars( pEnv, regType, regStr);
		SafeReleaseUTFChars( pEnv, domain, domainStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}


static void DNSSD_API	ServiceRegisterReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags,
											 DNSServiceErrorType errorCode, const char *serviceName,
											 const char *regType, const char *domain, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	
	SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
			(*pContext->Env)->CallVoidMethod( pContext->Env, pContext->ClientObj, pContext->Callback,
											 pContext->JavaObj, flags,
											 (*pContext->Env)->NewStringUTF( pContext->Env, serviceName),
											 (*pContext->Env)->NewStringUTF( pContext->Env, regType),
											 (*pContext->Env)->NewStringUTF( pContext->Env, domain));
		}
		else
			ReportError( pContext->Env, pContext->ClientObj, pContext->JavaObj, errorCode);
	}
	TeardownCallbackState();
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRegistration_BeginRegister( JNIEnv *pEnv, jobject pThis,
																			jint ifIndex, jint flags, jstring serviceName, jstring regType,
																			jstring domain, jstring host, jint port, jbyteArray txtRecord)
{
	//syslog(LOG_ERR, "BR");
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	jbyte					*pBytes;
	jsize					numBytes;
	
	//syslog(LOG_ERR, "BR: contextField %d", contextField);
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "serviceRegistered",
							  "(Lcom/apple/dnssd/DNSSDRegistration;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		const char	*servStr = SafeGetUTFChars( pEnv, serviceName);
		const char	*regStr = SafeGetUTFChars( pEnv, regType);
		const char	*domainStr = SafeGetUTFChars( pEnv, domain);
		const char	*hostStr = SafeGetUTFChars( pEnv, host);
		
		//syslog(LOG_ERR, "BR: regStr %s", regStr);
		
		// Since Java ints are defined to be big-endian, we de-canonicalize 'port' from a 
		// big-endian number into a 16-bit pattern here.
		uint16_t	portBits = port;
		portBits = ( ((unsigned char*) &portBits)[0] << 8) | ((unsigned char*) &portBits)[1];
		
		pBytes = txtRecord ? (*pEnv)->GetByteArrayElements( pEnv, txtRecord, NULL) : NULL;
		numBytes = txtRecord ? (*pEnv)->GetArrayLength( pEnv, txtRecord) : 0;
		
		err = DNSServiceRegister( &pContext->ServiceRef, flags, ifIndex, servStr, regStr,  
								 domainStr, hostStr, portBits,
								 numBytes, pBytes, ServiceRegisterReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
		
		if ( pBytes != NULL)
			(*pEnv)->ReleaseByteArrayElements( pEnv, txtRecord, pBytes, 0);
		
		SafeReleaseUTFChars( pEnv, serviceName, servStr);
		SafeReleaseUTFChars( pEnv, regType, regStr);
		SafeReleaseUTFChars( pEnv, domain, domainStr);
		SafeReleaseUTFChars( pEnv, host, hostStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRegistration_AddRecord( JNIEnv *pEnv, jobject pThis,
																		jint flags, jint rrType, jbyteArray rData, jint ttl, jobject destObj)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	jclass					destCls = (*pEnv)->GetObjectClass( pEnv, destObj);
	jfieldID				recField = (*pEnv)->GetFieldID( pEnv, destCls, "fRecord", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	jbyte					*pBytes;
	jsize					numBytes;
	DNSRecordRef			recRef;
	
	if ( contextField != 0)
		pContext = (OpContext*) (*pEnv)->GetIntField( pEnv, pThis, contextField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return kDNSServiceErr_BadParam;
	
	pBytes = (*pEnv)->GetByteArrayElements( pEnv, rData, NULL);
	numBytes = (*pEnv)->GetArrayLength( pEnv, rData);
	
	err = DNSServiceAddRecord( pContext->ServiceRef, &recRef, flags, rrType, numBytes, pBytes, ttl);
	if ( err == kDNSServiceErr_NoError)
	{
		(*pEnv)->SetIntField( pEnv, destObj, recField, (jint) recRef);
	}
	
	if ( pBytes != NULL)
		(*pEnv)->ReleaseByteArrayElements( pEnv, rData, pBytes, 0);
	
	return err;
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSRecord_Update( JNIEnv *pEnv, jobject pThis,
																  jint flags, jbyteArray rData, jint ttl)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				ownerField = (*pEnv)->GetFieldID( pEnv, cls, "fOwner", "Lcom/apple/dnssd/AppleService;");
	jfieldID				recField = (*pEnv)->GetFieldID( pEnv, cls, "fRecord", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	jbyte					*pBytes;
	jsize					numBytes;
	DNSRecordRef			recRef = NULL;
	
	if ( ownerField != 0)
	{
		jobject		ownerObj = (*pEnv)->GetObjectField( pEnv, pThis, ownerField);
		jclass		ownerClass = (*pEnv)->GetObjectClass( pEnv, ownerObj);
		jfieldID	contextField = (*pEnv)->GetFieldID( pEnv, ownerClass, "fNativeContext", "I");
		if ( contextField != 0)
			pContext = (OpContext*) (*pEnv)->GetIntField( pEnv, ownerObj, contextField);
	}
	if ( recField != 0)
		recRef = (DNSRecordRef) (*pEnv)->GetIntField( pEnv, pThis, recField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return kDNSServiceErr_BadParam;
	
	pBytes = (*pEnv)->GetByteArrayElements( pEnv, rData, NULL);
	numBytes = (*pEnv)->GetArrayLength( pEnv, rData);
	
	err = DNSServiceUpdateRecord( pContext->ServiceRef, recRef, flags, numBytes, pBytes, ttl);
	
	if ( pBytes != NULL)
		(*pEnv)->ReleaseByteArrayElements( pEnv, rData, pBytes, 0);
	
	return err;
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSRecord_Remove( JNIEnv *pEnv, jobject pThis)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				ownerField = (*pEnv)->GetFieldID( pEnv, cls, "fOwner", "Lcom/apple/dnssd/AppleService;");
	jfieldID				recField = (*pEnv)->GetFieldID( pEnv, cls, "fRecord", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	DNSRecordRef			recRef = NULL;
	
	if ( ownerField != 0)
	{
		jobject		ownerObj = (*pEnv)->GetObjectField( pEnv, pThis, ownerField);
		jclass		ownerClass = (*pEnv)->GetObjectClass( pEnv, ownerObj);
		jfieldID	contextField = (*pEnv)->GetFieldID( pEnv, ownerClass, "fNativeContext", "I");
		if ( contextField != 0)
			pContext = (OpContext*) (*pEnv)->GetIntField( pEnv, ownerObj, contextField);
	}
	if ( recField != 0)
		recRef = (DNSRecordRef) (*pEnv)->GetIntField( pEnv, pThis, recField);
	if ( pContext == NULL || pContext->ServiceRef == NULL)
		return kDNSServiceErr_BadParam;
	
	err = DNSServiceRemoveRecord( pContext->ServiceRef, recRef, 0);
	
	return err;
}


JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRecordRegistrar_CreateConnection( JNIEnv *pEnv, jobject pThis)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "recordRegistered", "(Lcom/apple/dnssd/DNSRecord;I)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		err = DNSServiceCreateConnection( &pContext->ServiceRef);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}

struct RecordRegistrationRef
{
	OpContext		*Context;
	jobject			RecordObj;
};
typedef struct RecordRegistrationRef	RecordRegistrationRef;

static void DNSSD_API	RegisterRecordReply( DNSServiceRef sdRef _UNUSED, 
											DNSRecordRef recordRef _UNUSED, DNSServiceFlags flags, 
											DNSServiceErrorType errorCode, void *context)
{
	RecordRegistrationRef	*regEnvelope = (RecordRegistrationRef*) context;
	OpContext		*pContext = regEnvelope->Context;
	
	SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{	
		if ( errorCode == kDNSServiceErr_NoError)
		{	
			(*pContext->Env)->CallVoidMethod( pContext->Env, pContext->ClientObj, pContext->Callback, 
											 regEnvelope->RecordObj, flags);
		}
		else
			ReportError( pContext->Env, pContext->ClientObj, pContext->JavaObj, errorCode);
	}
	
	(*pContext->Env)->DeleteWeakGlobalRef( pContext->Env, regEnvelope->RecordObj);
	free( regEnvelope);
	
	TeardownCallbackState();
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleRecordRegistrar_RegisterRecord( JNIEnv *pEnv, jobject pThis, 
																				jint flags, jint ifIndex, jstring fullname, jint rrType, jint rrClass, 
																				jbyteArray rData, jint ttl, jobject destObj)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	jclass					destCls = (*pEnv)->GetObjectClass( pEnv, destObj);
	jfieldID				recField = (*pEnv)->GetFieldID( pEnv, destCls, "fRecord", "I");
	const char				*nameStr = SafeGetUTFChars( pEnv, fullname);
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	jbyte					*pBytes;
	jsize					numBytes;
	DNSRecordRef			recRef;
	RecordRegistrationRef	*regEnvelope;
	
	if ( contextField != 0)
		pContext = (OpContext*) (*pEnv)->GetIntField( pEnv, pThis, contextField);
	if ( pContext == NULL || pContext->ServiceRef == NULL || nameStr == NULL)
		return kDNSServiceErr_BadParam;
	
	regEnvelope = calloc( 1, sizeof *regEnvelope);
	if ( regEnvelope == NULL)
		return kDNSServiceErr_NoMemory;
	regEnvelope->Context = pContext;
	regEnvelope->RecordObj = (*pEnv)->NewWeakGlobalRef( pEnv, destObj);	// must convert local ref to global to cache
	
	pBytes = (*pEnv)->GetByteArrayElements( pEnv, rData, NULL);
	numBytes = (*pEnv)->GetArrayLength( pEnv, rData);
	
	err = DNSServiceRegisterRecord( pContext->ServiceRef, &recRef, flags, ifIndex, 
								   nameStr, rrType, rrClass, numBytes, pBytes, ttl,
								   RegisterRecordReply, regEnvelope);
	
	if ( err == kDNSServiceErr_NoError)
	{
		(*pEnv)->SetIntField( pEnv, destObj, recField, (jint) recRef);
	}
	else
	{
		if ( regEnvelope->RecordObj != NULL)
			(*pEnv)->DeleteWeakGlobalRef( pEnv, regEnvelope->RecordObj);
		free( regEnvelope);
	}
	
	if ( pBytes != NULL)
		(*pEnv)->ReleaseByteArrayElements( pEnv, rData, pBytes, 0);
	
	SafeReleaseUTFChars( pEnv, fullname, nameStr);
	
	return err;
}


static void DNSSD_API	ServiceQueryReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
										  DNSServiceErrorType errorCode, const char *serviceName,
										  uint16_t rrtype, uint16_t rrclass, uint16_t rdlen,
										  const void *rdata, uint32_t ttl, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	jbyteArray		rDataObj;
	jbyte			*pBytes;
	
	SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL && 
		NULL != ( rDataObj = (*pContext->Env)->NewByteArray( pContext->Env, rdlen)))
	{	
		if ( errorCode == kDNSServiceErr_NoError)
		{
			// Initialize rDataObj with contents of rdata
			pBytes = (*pContext->Env)->GetByteArrayElements( pContext->Env, rDataObj, NULL);
			memcpy( pBytes, rdata, rdlen);
			(*pContext->Env)->ReleaseByteArrayElements( pContext->Env, rDataObj, pBytes, JNI_COMMIT);
			
			(*pContext->Env)->CallVoidMethod( pContext->Env, pContext->ClientObj, pContext->Callback,
											 pContext->JavaObj, flags, interfaceIndex,
											 (*pContext->Env)->NewStringUTF( pContext->Env, serviceName),
											 rrtype, rrclass, rDataObj, ttl);
		}
		else
			ReportError( pContext->Env, pContext->ClientObj, pContext->JavaObj, errorCode);
	}
	TeardownCallbackState();
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleQuery_CreateQuery( JNIEnv *pEnv, jobject pThis,
																   jint flags, jint ifIndex, jstring serviceName, jint rrtype, jint rrclass)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "queryAnswered",
							  "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;II[BI)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		const char	*servStr = SafeGetUTFChars( pEnv, serviceName);
		
		err = DNSServiceQueryRecord( &pContext->ServiceRef, flags, ifIndex, servStr,
									rrtype, rrclass, ServiceQueryReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
		
		SafeReleaseUTFChars( pEnv, serviceName, servStr);
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}


static void DNSSD_API	DomainEnumReply( DNSServiceRef sdRef _UNUSED, DNSServiceFlags flags, uint32_t interfaceIndex,
										DNSServiceErrorType errorCode, const char *replyDomain, void *context)
{
	OpContext		*pContext = (OpContext*) context;
	
	SetupCallbackState( &pContext->Env);
	
	if ( pContext->ClientObj != NULL && pContext->Callback != NULL)
	{
		if ( errorCode == kDNSServiceErr_NoError)
		{
			(*pContext->Env)->CallVoidMethod( pContext->Env, pContext->ClientObj,
											 ( flags & kDNSServiceFlagsAdd) != 0 ? pContext->Callback : pContext->Callback2,
											 pContext->JavaObj, flags, interfaceIndex,
											 (*pContext->Env)->NewStringUTF( pContext->Env, replyDomain));
		}
		else
			ReportError( pContext->Env, pContext->ClientObj, pContext->JavaObj, errorCode);
	}
	TeardownCallbackState();
}

JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDomainEnum_BeginEnum( JNIEnv *pEnv, jobject pThis,
																	  jint flags, jint ifIndex)
{
	jclass					cls = (*pEnv)->GetObjectClass( pEnv, pThis);
	jfieldID				contextField = (*pEnv)->GetFieldID( pEnv, cls, "fNativeContext", "I");
	OpContext				*pContext = NULL;
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	
	if ( contextField != 0)
		pContext = NewContext( pEnv, pThis, "domainFound",
							  "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;)V");
	else
		err = kDNSServiceErr_BadParam;
	
	if ( pContext != NULL)
	{
		pContext->Callback2 = (*pEnv)->GetMethodID( pEnv,
												   (*pEnv)->GetObjectClass( pEnv, pContext->ClientObj),
												   "domainLost", "(Lcom/apple/dnssd/DNSSDService;IILjava/lang/String;)V");
		
		err = DNSServiceEnumerateDomains( &pContext->ServiceRef, flags, ifIndex,
										 DomainEnumReply, pContext);
		if ( err == kDNSServiceErr_NoError)
		{
			(*pEnv)->SetIntField( pEnv, pThis, contextField, (jint) pContext);
		}
	}
	else
		err = kDNSServiceErr_NoMemory;
	
	return err;
}


JNIEXPORT jint JNICALL Java_com_apple_dnssd_AppleDNSSD_ConstructName( JNIEnv *pEnv, jobject pThis _UNUSED,
																	 jstring serviceName, jstring regtype, jstring domain, jobjectArray pOut)
{
	DNSServiceErrorType		err = kDNSServiceErr_NoError;
	const char				*nameStr = SafeGetUTFChars( pEnv, serviceName);
	const char				*regStr = SafeGetUTFChars( pEnv, regtype);
	const char				*domStr = SafeGetUTFChars( pEnv, domain);
	char					buff[ kDNSServiceMaxDomainName + 1];
	
	err = DNSServiceConstructFullName( buff, nameStr, regStr, domStr);
	
	if ( err == kDNSServiceErr_NoError)
	{
		// pOut is expected to be a String[1] array.
		(*pEnv)->SetObjectArrayElement( pEnv, pOut, 0, (*pEnv)->NewStringUTF( pEnv, buff));
	}
	
	SafeReleaseUTFChars( pEnv, serviceName, nameStr);
	SafeReleaseUTFChars( pEnv, regtype, regStr);
	SafeReleaseUTFChars( pEnv, domain, domStr);
	
	return err;
}

JNIEXPORT void JNICALL Java_com_apple_dnssd_AppleDNSSD_ReconfirmRecord( JNIEnv *pEnv, jobject pThis _UNUSED,
																	   jint flags, jint ifIndex, jstring fullName,
																	   jint rrtype, jint rrclass, jbyteArray rdata)
{
	jbyte					*pBytes;
	jsize					numBytes;
	const char				*nameStr = SafeGetUTFChars( pEnv, fullName);
	
	pBytes = (*pEnv)->GetByteArrayElements( pEnv, rdata, NULL);
	numBytes = (*pEnv)->GetArrayLength( pEnv, rdata);
	
	DNSServiceReconfirmRecord( flags, ifIndex, nameStr, rrtype, rrclass, numBytes, pBytes);
	
	if ( pBytes != NULL)
		(*pEnv)->ReleaseByteArrayElements( pEnv, rdata, pBytes, 0);
	
	SafeReleaseUTFChars( pEnv, fullName, nameStr);
}

#define LOCAL_ONLY_NAME "loo"

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


#if defined(_WIN32)
static char*
if_indextoname( DWORD ifIndex, char * nameBuff)
{
	PIP_ADAPTER_INFO	pAdapterInfo = NULL;
	PIP_ADAPTER_INFO	pAdapter = NULL;
	DWORD				dwRetVal = 0;
	char			*	ifName = NULL;
	ULONG				ulOutBufLen = 0;
	
	if (GetAdaptersInfo( NULL, &ulOutBufLen) != ERROR_BUFFER_OVERFLOW)
	{
		goto exit;
	}
	
	pAdapterInfo = (IP_ADAPTER_INFO *) malloc(ulOutBufLen); 
	
	if (pAdapterInfo == NULL)
	{
		goto exit;
	}
	
	dwRetVal = GetAdaptersInfo( pAdapterInfo, &ulOutBufLen );
	
	if (dwRetVal != NO_ERROR)
	{
		goto exit;
	}
	
	pAdapter = pAdapterInfo;
	while (pAdapter)
	{
		if (pAdapter->Index == ifIndex)
		{
			// It would be better if we passed in the length of nameBuff to this
			// function, so we would have absolute certainty that no buffer
			// overflows would occur.  Buffer overflows *shouldn't* occur because
			// nameBuff is of size MAX_ADAPTER_NAME_LENGTH.
			strcpy( nameBuff, pAdapter->AdapterName );
			ifName = nameBuff;
			break;
		}
		
		pAdapter = pAdapter->Next;
	}
	
exit:
	
	if (pAdapterInfo != NULL)
	{
		free( pAdapterInfo );
		pAdapterInfo = NULL;
	}
	
	return ifName;
}


static DWORD
if_nametoindex( const char * nameStr )
{
	PIP_ADAPTER_INFO	pAdapterInfo = NULL;
	PIP_ADAPTER_INFO	pAdapter = NULL;
	DWORD				dwRetVal = 0;
	DWORD				ifIndex = 0;
	ULONG				ulOutBufLen = 0;

	if (GetAdaptersInfo( NULL, &ulOutBufLen) != ERROR_BUFFER_OVERFLOW)
	{
		goto exit;
	}

	pAdapterInfo = (IP_ADAPTER_INFO *) malloc(ulOutBufLen); 

	if (pAdapterInfo == NULL)
	{
		goto exit;
	}

	dwRetVal = GetAdaptersInfo( pAdapterInfo, &ulOutBufLen );
	
	if (dwRetVal != NO_ERROR)
	{
		goto exit;
	}

	pAdapter = pAdapterInfo;
	while (pAdapter)
	{
		if (strcmp(pAdapter->AdapterName, nameStr) == 0)
		{
			ifIndex = pAdapter->Index;
			break;
		}
  
		pAdapter = pAdapter->Next;
	}

exit:

	if (pAdapterInfo != NULL)
	{
		free( pAdapterInfo );
		pAdapterInfo = NULL;
	}

	return ifIndex;
}
#endif


*/


//Muss an den schluss!!!!
int main() {
 
    AS3_Val hasAutoCallbacksField = AS3_False();
    
	AS3_Val initMethod = AS3_Function( NULL, InitLibrary );
	//AS3_Val haltOperationMethod = AS3_Function( NULL, HaltOperation );
	//AS3_Val blockForDataMethod = AS3_Function(NULL, BlockForData);
	//AS3_Val processResultsMethod = AS3_Function(NULL, ProcessResults);
	//AS3_Val createBrowserMethod = AS3_Function(NULL, CreateBrowser);
	
	// construct an object that holds references to the functions
	AS3_Val result = AS3_Object( "InitLibrary:AS3ValType",initMethod);
	//AS3_Val result = AS3_Object( "hasAutoCallbacks: IntType",hasAutoCallbacksField);

								//haltOperationMethod,
								//blockForDataMethod,
								//processResultsMethod,
								//createBrowserMethod);
	
	
	// Release
	AS3_Release( initMethod );
    AS3_Release( hasAutoCallbacksField );
	//AS3_Release( haltOperationMethod );
	//AS3_Release( blockForDataMethod );
	//AS3_Release( processResultsMethod );
	// notify that we initialized -- THIS DOES NOT RETURN!
	AS3_LibInit( result );
	
	// should never get here!
	return 0;
}
