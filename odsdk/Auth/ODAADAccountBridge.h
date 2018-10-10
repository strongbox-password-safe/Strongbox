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

@class ADTokenCacheStoreItem, ODAccountSession, ODServiceInfo;

#import <Foundation/Foundation.h>

@interface ODAADAccountBridge : NSObject

/**
 Converts an ODAccountSession to an ADTokenCacheStoreItem for use with ADAL.
 @param  account The account session to convert.
 @warning account Must not be nil.
 @return ADTokenCacheStoreItem An equivalent representation for use with ADAL.
 @see accountSessionFromCacheItem:ServiceInfo:
 */
+ (ADTokenCacheStoreItem *)cacheItemFromAccountSession:(ODAccountSession *)account;

/**
 Converts an ADTokenCacheStoreItem to an ODAccountSession.
 @param  cacheStoreItem ADAL cache item to be used to convert.
 @param serviceInfo The service info for the ODAccountSession.
 @warning Service info and cacheStoreItem must not be nil.
 @return ODAccountSession The converted account session.
 */
+ (ODAccountSession *)accountSessionFromCacheItem:(ADTokenCacheStoreItem *)cacheStoreItem serviceInfo:(ODServiceInfo *)serviceInfo;

/**
 Encodes the input string in a format that will not be semantically changed when ADAL normalizes it
 @param input The string to be encoded in an ADAL-normalization-safe manner
 */
+ (NSString*)adalSafeUserIdFromString:(NSString*)input;

/**
 Decodes the given ADAL-normalization-safe encoded user ID to a plaintext string
 @param userId The user ID to be decoded from ADAL-normalization-safe form
 */
+ (NSString*)stringFromAdalSafeUserId:(NSString*)userId;

@end
