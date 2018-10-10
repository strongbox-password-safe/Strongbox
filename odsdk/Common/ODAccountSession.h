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


@class ODServiceInfo;

#import <Foundation/Foundation.h>

/**
 The `ODAccountSession` object is a property bag for storing information needed to make authentication requests.
 @see https://dev.onedrive.com/auth/readme.htm.
 */
@interface ODAccountSession : NSObject <NSCopying>

/**
 The access token for the user.
*/
@property NSString *accessToken;

/**
 The time stamp indicating when the access token expires
 */
@property NSDate *expires;

/**
 The refresh token to when refreshing the access token. This may be nil.
 */
@property NSString *refreshToken;

/**
 The users accountId. A unique string.
 */
@property (readonly) NSString *accountId;

/**
 The ServiceInfo object used by the account session.
 @see ODServiceInfo
 */
@property (readonly) ODServiceInfo *serviceInfo;

/**
 Creates an ODAccountSession.
 @param accountId The accountId of the user. Must not be nil.
 @param accessToken The access token for the user. Must not be nil.
 @param expires The datetime stamp indicating when the token expires. Must not be nil.
 @param refreshToken The refresh token to use when refreshing the access token.
 @param serviceInfo The serviceInfo object.
 */
- (instancetype) initWithId:(NSString *)accountId
                accessToken:(NSString *)accessToken
                    expires:(NSDate *)expires
               refreshToken:(NSString *)refreshToken
                serviceInfo:(ODServiceInfo *)serviceInfo;

/**
 Creates an ODAccountSession from a dictionary.
 @param dictionary A dictionary containing account session information. Must not be nil.
 @param serviceInfo The serviceInfo for the account session.
 @see initWithId:token:expires:refresh:serviceInfo:
 @warning The dictionary must contain Strings for the following values:
 
 1. OD_AUTH_EXPIRES - Ticks since 1970, represented as an NSString
 2. OD_AUTH_USER_ID - The accountId
 3. OD_AUTH_ACCESS_TOKEN - The access token

 It may also contain:
 
 -  OD_AUTH_REFRESH_TOKEN - The refresh token to use when the access token expires.
 
 */
- (instancetype) initWithDictionary:(NSDictionary *)dictionary serviceInfo:(ODServiceInfo *)serviceInfo;

/**
 Creates an NSDictionary of the session containing all of the properties except the service info object.
 @returns NSDictionary
 */
- (NSDictionary *)toDictionary;

/**
 The service info flags.
 @returns NSDictionary of service info flags.
 @see [ODServiceInfo flags]
 */
- (NSDictionary *)sessionFlags;

@end
