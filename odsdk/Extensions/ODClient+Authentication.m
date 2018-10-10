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

#import "ODClient+Authentication.h"
#import "ODAccountSession.h"
#import "ODServiceInfo.h"
#import "ODAppConfiguration.h"

@implementation ODClient (Authentication)

+ (ODClient *)currentClientWithAppConfig:(ODAppConfiguration *)appConfig
{
    // There must be at least one App Id
    NSParameterAssert(appConfig.microsoftAccountAppId || appConfig.activeDirectoryAppId);
    
    ODClient *currentClient = nil;
    ODAccountSession *session = [ODClient currentSessionFromAccountStore:appConfig.accountStore];
    if (session){
        [appConfig.logger logWithLevel:ODLogInfo message:@"Load %@ as current session", session.accountId];
        if (appConfig.authProvider){
            [appConfig.logger logWithLevel:ODLogVerbose message:@"Loading client with %@ as auth provider", appConfig.authProvider];
            currentClient = [ODClient clientWithAuthProvider:appConfig.authProvider accountSession:session httpProvider:appConfig.httpProvider logger:appConfig.logger];
        }
        else {
            currentClient = [ODClient clientWithAccountSession:session httpProvider:appConfig.httpProvider accountStore:appConfig.accountStore logger:appConfig.logger];
        }
    }
    return currentClient;
}

+ (NSArray *)clientsFromAppConfig:(ODAppConfiguration *)appConfig
{
    // There must be at least one App Id
    NSParameterAssert(appConfig.microsoftAccountAppId || appConfig.activeDirectoryAppId);
    
    NSArray *clients = nil;
    if (appConfig.accountStore && appConfig.authProvider){
        clients = [ODClient clientsFromAccountStore:appConfig.accountStore withAuthProvider:appConfig.authProvider httpProvider:appConfig.httpProvider logger:appConfig.logger];
    }
    else if (appConfig.accountStore){
        clients = [ODClient clientsFromAccountStore:appConfig.accountStore httpProvider:appConfig.httpProvider logger:appConfig.logger];
    }
    return clients;
}

+ (NSArray *)clientsFromAccountStore:(id <ODAccountStore> )accountStore withAuthProvider:(id <ODAuthProvider>)authProvider httpProvider:(id <ODHttpProvider> )httpProvider logger:(id <ODLogger>)logger
{
    NSParameterAssert(accountStore);
    NSParameterAssert(authProvider);
    NSMutableArray *clients = [NSMutableArray array];
    [[accountStore loadAccounts] enumerateObjectsUsingBlock:^(ODAccountSession *session, NSUInteger index, BOOL *stop){
        [clients addObject:[ODClient clientWithAuthProvider:authProvider accountSession:session httpProvider:httpProvider logger:logger]];
    }];
    return clients;
}

+ (NSArray *)clientsFromAccountStore:(id <ODAccountStore> )accountStore httpProvider:(id <ODHttpProvider>)httpProvider logger:(id <ODLogger>)logger
{
    NSParameterAssert(accountStore);
    
    NSMutableArray *clients = [NSMutableArray array];
    [[accountStore loadAccounts] enumerateObjectsUsingBlock:^(ODAccountSession *session, NSUInteger index, BOOL *stop){
        [clients addObject:[ODClient clientWithAccountSession:session httpProvider:httpProvider accountStore:accountStore logger:logger]];
    }];
    return clients;
}

+ (ODClient *)clientWithAuthProvider:(id <ODAuthProvider>)authProvider
                      accountSession:(ODAccountSession *)accountSession
                        httpProvider:(id <ODHttpProvider>)httpProvider
                              logger:(id <ODLogger>)logger
{
    NSParameterAssert(authProvider);
    NSParameterAssert(accountSession);
    
    ODClient *client = [[ODClient alloc] init];
    client.logger = logger;
    if ([authProvider respondsToSelector:@selector(authenticateWithAccountSession:completion:)]){
        [authProvider authenticateWithAccountSession:accountSession completion:nil];
    }
    else {
        [logger logWithLevel:ODLogWarn message:@"Auth provider doesn't respond to authenticateWithAccountSession:completion:"];
    }
    [client onAuthenticationCompletionWithError:nil authProvider:authProvider httpProvider:httpProvider completion:nil];
    return client;
}

+ (ODClient *)clientWithAccountSession:(ODAccountSession *)accountSession
                          httpProvider:(id <ODHttpProvider>)httpProvider
                          accountStore:(id <ODAccountStore>)accountStore
                                logger:(id <ODLogger >)logger
{
    NSParameterAssert(accountSession);
    NSParameterAssert(accountStore);
    
    id <ODAuthProvider> authProvider = [accountSession.serviceInfo authProviderWithURLSession:httpProvider
                                                                                 accountStore:accountStore
                                                                                       logger:logger];
    return [ODClient clientWithAuthProvider:authProvider accountSession:accountSession httpProvider:httpProvider logger:logger];
}

+ (ODAccountSession*)currentSessionFromAccountStore:(id <ODAccountStore>)accountStore
{
    ODAccountSession *session = nil;
    if (accountStore){
        session = [accountStore loadCurrentAccount];
    }
    return session;
}

+ (void)authenticatedClientWithAppConfig:(ODAppConfiguration *)appConfig completion:(void (^)(ODClient *client, NSError *error))completion
{
    ODClient *client = [[ODClient alloc] init];
    client.logger = appConfig.logger;
    [client authenticateWithAppConfig:appConfig completion:^(NSError *error){
        if (!error){
            completion(client, error);
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void)authenticateWithAuthProvider:(id <ODAuthProvider> )authProvider
                        httpProvider:(id <ODHttpProvider> )httpProvider
                              logger:(id <ODLogger>)logger
                          completion:(void (^)(NSError *error))completion
{
    
    UIViewController *rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [self authenticateWithAuthProvider:authProvider
                            httpProvider:httpProvider
                                logger:logger
                        viewController:rootViewController
                            completion:completion];
}

- (void)authenticateWithAuthProvider:(id<ODAuthProvider>)authProvider
                        httpProvider:(id<ODHttpProvider>)httpProvider
                              logger:(id <ODLogger>)logger
                      viewController:(UIViewController *)viewController
                          completion:(void (^)(NSError *))completion
{
    NSParameterAssert(authProvider);
    NSParameterAssert(httpProvider);
    NSParameterAssert(viewController);
    if ([authProvider respondsToSelector:@selector(authenticateWithViewController:completion:)]){
        [authProvider authenticateWithViewController:viewController completion:^(NSError *error){
            [self onAuthenticationCompletionWithError:error authProvider:authProvider httpProvider:httpProvider completion:completion];
        }];
    }
    else{
        [logger logWithLevel:ODLogWarn message:@"Auth provider doesn't respond to authenticateWithViewController"];
    }
}

- (void)authenticateWithAppConfig:(ODAppConfiguration *)appConfig
                      completion:(void (^)(NSError *error))completion
{
    NSParameterAssert(appConfig);
    
    __block UIViewController *rootViewController = appConfig.parentAuthController;
    if (appConfig.authProvider){
        [self authenticateWithAuthProvider:appConfig.authProvider
                              httpProvider:appConfig.httpProvider
                                    logger:appConfig.logger
                            viewController:rootViewController
                                completion:completion];
    }
    else {
        // We may not know which authentication service to use we have to discover it
        [appConfig.serviceInfoProvider getServiceInfoWithViewController:rootViewController
                                                       appConfiguration:appConfig
                                                             completion:^(UIViewController *presentedViewController, ODServiceInfo *serviceInfo, NSError *error){
                                                                if (!error){
                                                                    id <ODAuthProvider> authProvider = [serviceInfo authProviderWithURLSession:appConfig.httpProvider
                                                                                                                                  accountStore:appConfig.accountStore
                                                                                                                                        logger:appConfig.logger];
                                                                    [self authenticateWithAuthProvider:authProvider
                                                                                          httpProvider:appConfig.httpProvider
                                                                                                logger:appConfig.logger
                                                                                        viewController:(presentedViewController.parentViewController) ? presentedViewController.parentViewController : rootViewController
                                                                                            completion:completion];
                                                                }
                                                                else {
                                                                    if (presentedViewController){
                                                                        [presentedViewController dismissViewControllerAnimated:YES completion:nil];
                                                                    }
                                                                    completion(error);
                                                                }
        }];
    }
}


- (void)onAuthenticationCompletionWithError:(NSError *)error
                               authProvider:(id <ODAuthProvider>)authProvider
                               httpProvider:(id <ODHttpProvider>)httpProvider
                                 completion:(void (^)(NSError *error))completion
{
    if (!error){
        self.baseURL = [NSURL URLWithString:authProvider.baseURL];
        self.authProvider = authProvider;
        self.httpProvider = httpProvider;
    }
    if (completion){
        completion(error);
    }
}

@end
