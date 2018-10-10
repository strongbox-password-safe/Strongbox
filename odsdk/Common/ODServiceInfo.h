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


#import <Foundation/Foundation.h>
#import "ODHttpProvider.h"
#import "ODAuthProvider.h"
#import "ODAccountStoreProtocol.h"
#import "ODLoggerProtocol.h"
#import "ODAuthConstants.h"

/**
 The 'ODServiceInfo' object will provide information for the specific authentication service.
 */
@interface ODServiceInfo : NSObject <NSCoding>

/**
 This app's appId.
 */
@property NSString *appId;

/**
 The URL the authentication service will redirect to after the login was successful.
 @see https://dev.onedrive.com/auth/msa_oauth.htm
 */
@property NSString *redirectURL;

/**
 The URL to retrieve the token with the code from the authentication service.
 */
@property (readonly) NSString *tokenURL;

/**
 The URL to the authentication authority, this is just the host for authority not the full URL.
 */
@property (readonly) NSString *authorityURL;

/**
 The URL to logout of the session.  This may be nil.
 */
@property (readonly) NSString *logoutURL;

/**
 The resourceId of the service being access.
 This is mainly for Azure Active Directory, the first resourceId used is to the discovery service.
 It is usually the host of service being accessed.
 */
@property NSString *resourceId;

/**
 The URL to use to discovery the resource id. This may be nil.
 */
@property (readonly) NSString *discoveryServiceURL;

/**
 The email of the user. This may be nil.
 */
@property NSString *userEmail;

/**
 The Api Endpoint
 For Personal OneDrive, this will be https://api.onedrive.com/v1.0/
 */
@property NSString *apiEndpoint;

/**
 An array of strings containing the scopes for the authentication service. This may be nil.
 */
@property NSArray *scopes;

/**
 The Active Directory Capability. This may be nil.
 */
@property NSString *capability;

/**
 Flags for the given service, these are user defined.
 This may be nil or an empty dictionary
 */
@property (readonly) NSDictionary *flags;

/**
 The account type for the ServiceInfo.
 */
@property (readonly) ODAccountType accountType;

/**
 Creates and authentication provider with a given ODHttpProvider and ODAccountStore.
 @param  session The ODHttpProvider to be used for network requests.
 @param  accountStore The accountStore for the auth provider to use.
 @return ODAuthProvider An authentication provider to be used for correct service, created with the given parameters.
 */
- (id <ODAuthProvider>)authProviderWithURLSession:(id <ODHttpProvider>)session
                                     accountStore:(id <ODAccountStore>)accountStore
                                           logger:(id<ODLogger>)logger;


@end
