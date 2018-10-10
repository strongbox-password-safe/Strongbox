//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#ifndef OneDriveSDK_ODAuthConstants_h
#define OneDriveSDK_ODAuthConstants_h

typedef NS_ENUM(NSInteger, ODAccountType){
    ODUnknownAccount = 0,
    ODMSAAccount = 1,
    ODADAccount = 2,
};

/**
 Enum for the possible error types during the authentication process.
 These will be codes for the NSError.
 */
typedef NS_ENUM(NSInteger, ODAuthErrorType) {
    /** A network error occurred during authentication. */
    ODNetworkError,
    /** The authentication service had an error. */
    ODServiceError,
    /** The was an error serializing the response from the service. */
    ODSerializationError,
    /** The user canceled the authentication flow. */
    ODAuthCanceled,
    /** You do not have the correct account information. */
    ODInvalidAccountType
};

extern NSString * const OD_SDK_VERSION;

extern NSString * const OD_AUTH_ERROR_DOMAIN;
extern NSString * const OD_AUTH_ERROR_KEY;

extern NSString * const OD_API_HEADER_AUTHORIZATION;
extern NSString * const OD_API_HEADER_CONTENTTYPE;
extern NSString * const OD_API_HEADER_CONTENTTYPE_FORMENCODED;
extern NSString * const OD_API_HEADER_APPLICATION_JSON;
extern NSString * const OD_API_HEADER_ACCEPT;

extern NSString * const OD_AUTH_ACCESS_TOKEN;
extern NSString * const OD_AUTH_CODE;
extern NSString * const OD_AUTH_DISPLAY;
extern NSString * const OD_AUTH_DISPLAY_IOS_PHONE;
extern NSString * const OD_AUTH_CLIENTID;
extern NSString * const OD_AUTH_EXPIRES;
extern NSString * const OD_AUTH_GRANT_TYPE;
extern NSString * const OD_AUTH_GRANT_TYPE_AUTHCODE;
extern NSString * const OD_AUTH_REDIRECT_URI;
extern NSString * const OD_AUTH_REFRESH_TOKEN;
extern NSString * const OD_AUTH_RESPONSE_TYPE;
extern NSString * const OD_AUTH_SCOPE;
extern NSString * const OD_AUTH_TOKEN;
extern NSString * const OD_AUTH_SECRET;
extern NSString * const OD_AUTH_USER_ID;
extern NSString * const OD_AUTH_TOKEN_ID;
extern NSString * const OD_AUTH_USER_NAME;
extern NSString * const OD_AUTH_USER_EMAIL;

extern NSString * const OD_MSA_TELEMTRY_HEADER;
extern NSString * const OD_AAD_TELEMTRY_HEADER;
extern NSString * const OD_TELEMTRY_HEADER_VALUE_FORMAT;

extern NSString * const OD_DISCOVERY_ACCOUNT_TYPE;
extern NSString * const OD_DISCOVERY_ACCOUNT_TYPE_AAD;
extern NSString * const OD_DISCOVERY_ACCOUNT_TYPE_MSA;
extern NSString * const OD_DISCOVERY_SERVICE_RESOURCEID;
extern NSString * const OD_DISCOVERY_SERVICE_URL;
extern NSString * const OD_DISAMBIGUATION_URL;

extern NSString * const OD_MICROSOFT_ACCOUNT_ENDPOINT_HOST;
extern NSString * const OD_MICROSOFT_ACCOUNT_AUTH_URL;
extern NSString * const OD_MICROSOFT_ACCOUNT_TOKEN_URL;
extern NSString * const OD_MICROSOFT_ACCOUNT_REDIRECT_URL;
extern NSString * const OD_MICROSOFT_ACCOUNT_LOGOUT_URL;
extern NSString * const OD_MICROSOFT_ACCOUNT_API_VERSION;
extern NSString * const OD_MICROSOFT_ACCOUNT_ENDPOINT;

extern NSString * const OD_DISCOVERY_REDIRECT_URL;
extern NSString * const OD_MICROSOFT_ACCOUNT_ENDPOINT;

extern NSString * const OD_ACTIVE_DIRECTORY_AUTH_URL;
extern NSString * const OD_ACTIVE_DIRECTORY_AUTH_ENDPOINT_HOST;
extern NSString * const OD_ACTIVE_DIRECTORY_URL_SUFFIX;

extern NSString * const OD_MICROSOFT_ACCOUNT_API_VERSION;

#endif
