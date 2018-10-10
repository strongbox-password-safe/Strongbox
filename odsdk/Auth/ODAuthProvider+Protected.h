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

#ifndef iOSExplorer_ODAuthProvider_Protected_h
#define iOSExplorer_ODAuthProvider_Protected_h

#import "ODBaseAuthProvider.h"

@interface ODBaseAuthProvider()

@property id <ODHttpProvider> httpProvider;

@property id <ODAccountStore> accountStore;

@property ODServiceInfo *serviceInfo;

/**
 The proper telemtryHeaderField for the given service.
 */
@property (readonly) NSString *telemtryHeaderField;

/**
 Creates an error from a URL returned by an authentication service.
 @param url The URL returned by the service.
 @return An error object constructed from the url.
 */
- (NSError *)errorFromURL:(NSURL *)url;

/**
 Retrieves the token with the given authentication code.
 @param code The code retrieved from the OAuth Service using the code flow method.
 @param completion The completion handler to call when the request is complete.
 */
- (void)getTokenWithCode:(NSString *)code completion:(AuthCompletion)completion;

/**
 The authentication URL with query parameters used to start the authentication process.
 */
- (NSURL *)authURL;

/**
 Creates the first request to the authentication service.
 @return The request.
 */
- (NSURLRequest *)authRequest;

/**
 Creates the request to retrieve a token from the authentication service.
 @param  code The code retrieved from the initial auth request. @see authRequests.
 @return The request to be sent.
 */
- (NSURLRequest *)tokenRequestWithCode:(NSString *)code;

/**
 Creates a dictionary that contains the parameters for a refresh request from the authentication service.
 @param  refreshToken The refresh token acquired from the initial token requests. @see tokenRequestWithCode:
 @return A dictionary that contains the parameters as key value pairs.
 */
- (NSDictionary *)refreshRequestParametersWithRefreshToken:(NSString *)refreshToken;

/**
 Creates the refresh request with the given refreshToken.
 @param  refreshToken The token to use in the request.
 @return A request to the authentication service.
 */
- (NSURLRequest *)refreshRequestWithRefreshToken:(NSString *)refreshToken;

/**
 @return A request to log out of the current session.
 */
- (NSURLRequest *)logoutRequest;



@end

#endif
