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


#import "ODServiceInfo+Protected.h"
#import "ODAADServiceInfo.h"
#import "ODBusinessAuthProvider.h"
#import "ODAuthConstants.h"

@implementation ODAADServiceInfo

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self){
        //Migrate ApiEndpoint
        if (!_apiEndpoint){
            //old versions of the SDK only supported /_api/v2.0/me attached to resourceId
            _apiEndpoint = [_resourceId stringByAppendingPathComponent:[OD_ACTIVE_DIRECTORY_URL_SUFFIX copy]];
        }
    }
    return self;
}

- (instancetype)initWithClientId:(NSString *)clientId
                      capability:(NSString *)capability
                      resourceId:(NSString *)resourceId
                     apiEndpoint:(NSString *)apiEndpoint
                     redirectURL:(NSString *)redirectURL
                           flags:(NSDictionary *)flags
{
    NSParameterAssert(redirectURL);
    NSParameterAssert(apiEndpoint || [OD_DISCOVERY_SERVICE_URL containsString:resourceId]);
    
    self = [super initWithClientId:clientId scopes:nil flags:flags];
    if (self){
        _capability = capability;
        _redirectURL = redirectURL;
        _resourceId = resourceId;
        _apiEndpoint = apiEndpoint;
        _authorityURL = [OD_ACTIVE_DIRECTORY_AUTH_URL copy];
        _discoveryServiceURL = [OD_DISCOVERY_SERVICE_URL copy];
    }
    return self;
}

- (id <ODAuthProvider>)createAuthProviderWithSession:(id<ODHttpProvider> )session accountStore:(id <ODAccountStore>)accountStore logger:(id <ODLogger>)logger
{
    return [[ODBusinessAuthProvider alloc] initWithServiceInfo:self httpProvider:session accountStore:accountStore logger:logger];
}

- (ODAccountType)accountType
{
    return ODADAccount;
}

@end
