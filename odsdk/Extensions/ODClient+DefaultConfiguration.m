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

#import "ODClient+DefaultConfiguration.h"
#import "ODAppConfiguration+DefaultConfiguration.h"
#import "ODAccountSession.h"
#import "ODAuthProvider.h"

@implementation ODClient (DefaultConfiguration)

+ (void)clientWithCompletion:(ODClientAuthenticationCompletion)completion
{
    NSParameterAssert(completion);
    
    ODClient *client = [ODClient loadCurrentClient];
    if (client){
        completion(client, nil);
    }
    else{
        [ODClient authenticatedClientWithCompletion:completion];
    }
}

+ (void)authenticatedClientWithCompletion:(ODClientAuthenticationCompletion)completion
{
    [ODClient authenticatedClientWithAppConfig:[ODAppConfiguration defaultConfiguration] completion:completion];
}

+ (void)setCurrentClient:(ODClient *)client
{
    ODAccountSession *currentSession = nil;
    id <ODLogger> logger = client.logger;
    id <ODAccountStore> accountStore = [ODAppConfiguration defaultConfiguration].accountStore;
    if ([client.authProvider respondsToSelector:@selector(accountSession)]){
        currentSession = [client.authProvider accountSession];
    }
    else{
        [logger logWithLevel:ODLogWarn message:@"Auth provider doesn't respond to accountSession"];
    }
    if (currentSession && accountStore){
        [accountStore storeCurrentAccount:currentSession];
        [logger logWithLevel:ODLogInfo message:@"Setting %@ as the current session", currentSession.accountId];
    }
    else {
        [logger logWithLevel:ODLogWarn message:@"No account store or account session"];
    }
}

+ (ODClient *)loadCurrentClient
{
    return [ODClient currentClientWithAppConfig:[ODAppConfiguration defaultConfiguration]];
}

+ (ODClient *)loadClientWithAccountId:(NSString *)accountId
{
    __block ODClient *foundClient = nil;
    [[ODClient loadClients] enumerateObjectsUsingBlock:^(ODClient *client, NSUInteger index, BOOL *stop){
        if ([client.accountId isEqualToString:accountId]){
            foundClient = client;
            *stop = YES;
        }
    }];
    return foundClient;
}

+ (NSArray *)loadClients
{
    return [ODClient clientsFromAppConfig:[ODAppConfiguration defaultConfiguration]];
}

+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
                          scopes:(NSArray *)microsoftAccountScopes
                           flags:(NSDictionary *)microsoftAccountFlags
{
    NSParameterAssert(microsoftAccountAppId);
    NSParameterAssert(microsoftAccountScopes);
    // default to OneDrive
    NSString *onedriveApiEndpoint  = [NSString stringWithFormat:@"%@/%@", OD_MICROSOFT_ACCOUNT_ENDPOINT, OD_MICROSOFT_ACCOUNT_API_VERSION];
    [ODClient setMicrosoftAccountAppId:microsoftAccountAppId
                                scopes:microsoftAccountScopes
                                 flags:microsoftAccountFlags
                           apiEndpoint:onedriveApiEndpoint];
}

+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId scopes:(NSArray *)microsoftAccountScopes
{
    [ODClient setMicrosoftAccountAppId:microsoftAccountAppId scopes:microsoftAccountScopes flags:nil];
}

+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
                          scopes:(NSArray *)microsoftAccountScopes
                           flags:(NSDictionary *)microsoftAccountFlags
                     apiEndpoint:(NSString *)apiEndpoint
{
    ODAppConfiguration *defaultConfig = [ODAppConfiguration defaultConfiguration];
    defaultConfig.microsoftAccountAppId = microsoftAccountAppId;
    defaultConfig.microsoftAccountScopes = microsoftAccountScopes;
    defaultConfig.microsoftAccountFlags = microsoftAccountFlags;
    defaultConfig.microsoftAccountApiEndpoint = apiEndpoint;
}

+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId redirectURL:(NSString *)activeDirectoryRedirectURL
{
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId redirectURL:activeDirectoryRedirectURL flags:nil];
}

+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                    redirectURL:(NSString *)activeDirectoryRedirectURL
                          flags:(NSDictionary *)flags
{
    // Default to MyFiles for OneDrive for Business
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId
                           capability:@"MyFiles"
                           resourceId:nil
                          apiEndpoint:nil
                          redirectURL:activeDirectoryRedirectURL
                                flags:flags];
}

+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     capability:(NSString *)activeDirectoryCapability
                     resourceId:(NSString *)activeDirectoryResourceId
                    apiEndpoint:(NSString *)activeDirectoryApiEndpoint
                    redirectURL:(NSString *)activeDirectoryRedirectURL
                          flags:(NSDictionary *)activeDirectoryFlags
{
    NSParameterAssert(activeDirectoryAppId);
    NSParameterAssert(activeDirectoryRedirectURL);
    
    ODAppConfiguration *defaultConfig = [ODAppConfiguration defaultConfiguration];
    defaultConfig.activeDirectoryAppId = activeDirectoryAppId;
    defaultConfig.activeDirectoryCapability = activeDirectoryCapability;
    defaultConfig.activeDirectoryRedirectURL = activeDirectoryRedirectURL;
    defaultConfig.activeDirectoryFlags = activeDirectoryFlags;
    defaultConfig.activeDirectoryResourceId = activeDirectoryResourceId;
    defaultConfig.activeDirectoryApiEndpointURL = activeDirectoryApiEndpoint;
}

+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     resourceId:(NSString *)activeDirectoryResourceId
                    apiEndpoint:(NSString *)activeDirectoryApiEndpoint
                    redirectURL:(NSString *)activeDirectoryRedirectURL
{
    NSParameterAssert(activeDirectoryResourceId);
    
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId
                           capability:nil
                           resourceId:activeDirectoryResourceId
                          apiEndpoint:activeDirectoryApiEndpoint
                          redirectURL:activeDirectoryRedirectURL
                                flags:nil];
}

+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     capability:(NSString *)activeDirectoryCapability
                    redirectURL:(NSString *)activeDirectoryRedirectURL
{
    NSParameterAssert(activeDirectoryCapability);
    
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId
                           capability:activeDirectoryCapability
                           resourceId:nil
                          apiEndpoint:nil
                          redirectURL:activeDirectoryRedirectURL
                                flags:nil];
}

+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
          microsoftAccountScopes:(NSArray *)microsoftAccountScopes
           microsoftAccountFlags:(NSDictionary *)microsoftAccountFlags
            activeDirectoryAppId:(NSString *)activeDirectoryAppId
       activeDirectoryCapability:(NSString *)activeDirectoryCapability
      activeDirectoryRedirectURL:(NSString *)activeDirectoryRedirectURL
            activeDirectoryFlags:(NSDictionary *)activeDirectoryFlags
{
    [ODClient setMicrosoftAccountAppId:microsoftAccountAppId scopes:microsoftAccountScopes flags:microsoftAccountFlags];
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId
                           capability:activeDirectoryCapability
                           resourceId:nil
                          apiEndpoint:nil
                          redirectURL:activeDirectoryRedirectURL
                                flags:activeDirectoryFlags];
}

+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
          microsoftAccountScopes:(NSArray *)microsoftAccountScopes
           microsoftAccountFlags:(NSDictionary *)microsoftAccountFlags
            activeDirectoryAppId:(NSString *)activeDirectoryAppId
       activeDirectoryResourceId:(NSString *)activeDirectoryResourceId
      activeDirectoryApiEndpoint:(NSString *)activeDirectoryApiEndpoint
      activeDirectoryRedirectURL:(NSString *)activeDirectoryRedirectURL
            activeDirectoryFlags:(NSDictionary *)activeDirectoryFlags
{
    [ODClient setMicrosoftAccountAppId:microsoftAccountAppId scopes:microsoftAccountScopes flags:microsoftAccountFlags];
    [ODClient setActiveDirectoryAppId:activeDirectoryAppId
                           capability:nil
                           resourceId:activeDirectoryResourceId
                          apiEndpoint:activeDirectoryApiEndpoint
                          redirectURL:activeDirectoryRedirectURL
                                flags:activeDirectoryFlags];
}

+ (void)setAuthProvider:(id <ODAuthProvider>)authProvider
{
    [ODAppConfiguration defaultConfiguration].authProvider = authProvider;
}

+ (void)setAccountStore:(id <ODAccountStore>)accountStore
{
    [ODAppConfiguration defaultConfiguration].accountStore = accountStore;
}

+ (void)setHttpProvider:(id <ODHttpProvider>)httpProvider
{
    [ODAppConfiguration defaultConfiguration].httpProvider = httpProvider;
}

+ (void)setParentAuthController:(UIViewController *)parentAuthController
{
    [ODAppConfiguration defaultConfiguration].parentAuthController = parentAuthController;
}

+ (void)setLogger:(id <ODLogger>)logger
{
    [ODAppConfiguration defaultConfiguration].logger = logger;
}

+ (void)setDefaultLogLevel:(ODLogLevel)level
{
    [[ODAppConfiguration defaultConfiguration].logger setLogLevel:level];
}

- (void)setLogLevel:(ODLogLevel)level
{
    [self.logger setLogLevel:level];
}

- (NSString *)accountId
{
    return self.authProvider.accountSession.accountId;
}

@end
