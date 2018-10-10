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


#import "ODAccountSession.h"
#import "ODAuthConstants.h"
#import "ODServiceInfo.h"

@implementation ODAccountSession

-(instancetype) initWithId:(NSString *)accountId
               accessToken:(NSString *)accessToken
                   expires:(NSDate *)expires
              refreshToken:(NSString *)refreshToken
               serviceInfo:(ODServiceInfo *)serviceInfo
{
    NSParameterAssert(accessToken);
    NSParameterAssert(accountId);
    NSParameterAssert(expires);
    
    self = [super init];
    if (self){
        _accountId = accountId;
        _accessToken = accessToken;
        _expires = expires;
        _refreshToken = refreshToken;
        _serviceInfo = serviceInfo;
    }
    return  self;
}

- (instancetype) initWithDictionary:(NSDictionary *)dictionary serviceInfo:(ODServiceInfo *)serviceInfo;
{
    NSDate *expires = [NSDate dateWithTimeIntervalSince1970:[dictionary[OD_AUTH_EXPIRES] doubleValue]];
    return [self initWithId:dictionary[OD_AUTH_USER_ID]
                accessToken:dictionary[OD_AUTH_ACCESS_TOKEN]
                    expires:expires
               refreshToken:dictionary[OD_AUTH_REFRESH_TOKEN]
                serviceInfo:serviceInfo];
}

- (NSDictionary *)toDictionary
{
    NSInteger expiresInterval = [self.expires timeIntervalSince1970];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:self.accessToken, OD_AUTH_ACCESS_TOKEN,
                                                                                        self.accountId, OD_AUTH_USER_ID,
                                                                                        @(expiresInterval), OD_AUTH_EXPIRES, nil];
    if (self.refreshToken){
        dictionary[OD_AUTH_REFRESH_TOKEN] = self.refreshToken;
    }
    return dictionary;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    return [[ODAccountSession alloc] initWithDictionary:[self toDictionary] serviceInfo:self.serviceInfo];
}

- (NSDictionary *)sessionFlags
{
    return self.serviceInfo.flags;
}

@end
