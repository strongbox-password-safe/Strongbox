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

#import "ODServiceInfo.h"
#import "ODAuthConstants.h"
#import "ODAuthHelper.h"

@interface ODServiceInfo()

@property (readonly, nonatomic) id <ODAuthProvider> authProvider;

@end

@implementation ODServiceInfo

- (instancetype)initWithClientId:(NSString *)clientId scopes:(NSArray *)scopes flags:(NSDictionary *)flags 
{
    NSParameterAssert(clientId);
    
    self = [super init];
    if (self){
        _appId = clientId;
        _flags = flags;
        _scopes = scopes;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.appId forKey:@"clientId"];
    [aCoder encodeObject:self.authorityURL forKey:@"authority"];
    [aCoder encodeObject:self.redirectURL forKey:@"redirectURL"];
    [aCoder encodeObject:self.tokenURL forKey:@"tokenURL"];
    [aCoder encodeObject:self.resourceId forKey:@"resourceId"];
    [aCoder encodeObject:self.discoveryServiceURL forKey:@"discoveryServiceURL"];
    [aCoder encodeObject:self.flags forKey:@"flags"];
    [aCoder encodeObject:self.scopes forKey:@"scopes"];
    [aCoder encodeObject:self.logoutURL forKey:@"logoutURL"];
    [aCoder encodeObject:self.apiEndpoint forKey:@"apiEndpoint"];
    [aCoder encodeObject:self.capability forKey:@"capability"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self){
        _appId = [aDecoder decodeObjectForKey:@"clientId"];
        _authorityURL = [aDecoder decodeObjectForKey:@"authority"];
        _redirectURL = [aDecoder decodeObjectForKey:@"redirectURL"];
        _tokenURL = [aDecoder decodeObjectForKey:@"tokenURL"];
        _resourceId = [aDecoder decodeObjectForKey:@"resourceId"];
        _discoveryServiceURL = [aDecoder decodeObjectForKey:@"discoveryServiceURL"];
        _flags = [aDecoder decodeObjectForKey:@"flags"];
        _scopes = [aDecoder decodeObjectForKey:@"scopes"];
        _logoutURL = [aDecoder decodeObjectForKey:@"logoutURL"];
        _capability = [aDecoder decodeObjectForKey:@"capability"];
        _apiEndpoint = [aDecoder decodeObjectForKey:@"apiEndpoint"];
    }
    return self;
}

- (id<ODAuthProvider>)authProviderWithURLSession:(id<ODHttpProvider>)session
                                    accountStore:(id<ODAccountStore>)accountStore
                                          logger:(id <ODLogger>)logger
{
    if (!_authProvider){
        _authProvider = [self createAuthProviderWithSession:session accountStore:accountStore logger:logger];
    }
    return _authProvider;
}

- (id <ODAuthProvider>)createAuthProviderWithSession:(id<ODHttpProvider> )session
                                        accountStore:(id <ODAccountStore>)accountStore
                                              logger:(id <ODLogger> )logger
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

@end
