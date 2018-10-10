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

#import "ODMSAServiceInfo.h"
#import "ODServiceInfo+Protected.h"
#import "ODAuthConstants.h"
#import "ODPersonalAuthProvider.h"

@implementation ODMSAServiceInfo

- (instancetype)initWithClientId:(NSString *)clientId
                          scopes:(NSArray *)scopes
                           flags:(NSDictionary *)flags
                     apiEndpoint:(NSString *)apiEndpoint;
{
    NSParameterAssert(scopes);
    
    self = [super initWithClientId:clientId scopes:scopes flags:flags];
    if (self){
        _authorityURL = [OD_MICROSOFT_ACCOUNT_AUTH_URL copy];
        _tokenURL = [OD_MICROSOFT_ACCOUNT_TOKEN_URL copy];
        _apiEndpoint = apiEndpoint;
        _redirectURL = [OD_MICROSOFT_ACCOUNT_REDIRECT_URL copy];
        _logoutURL = [OD_MICROSOFT_ACCOUNT_LOGOUT_URL copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self){
        //Migrate the APIEndpoint from resource Id if this was loaded from an older SDK version
        if (!_apiEndpoint){
            _apiEndpoint = _resourceId;
        }
    }
    return self;
}

- (NSDictionary *)authRequestParameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:[super authRequestParameters]];
    params[OD_AUTH_SCOPE] = [self.scopes componentsJoinedByString:@" "];
    return params;
}

- (id <ODAuthProvider>)createAuthProviderWithSession:(id<ODHttpProvider> )session accountStore:(id <ODAccountStore>)accountStore logger:(id <ODLogger>)logger
{
    return [[ODPersonalAuthProvider alloc] initWithServiceInfo:self httpProvider:session accountStore:accountStore logger:logger];
}

- (ODAccountType)accountType
{
    return ODMSAAccount;
}

@end
