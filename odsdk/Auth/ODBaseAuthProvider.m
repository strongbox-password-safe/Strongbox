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


#import "ODBaseAuthProvider.h"
#import "ODAuthHelper.h"
#import "ODAccountSession.h"
#import "ODServiceInfo.h"
#import "ODAppConfiguration.h"
#import "ODAuthenticationViewController.h"
#import "ODAuthProvider+Protected.h"

@interface ODBaseAuthProvider ()
@property (nonatomic, strong) ODAuthenticationViewController *authViewController;
@property (nonatomic, strong) NSURLSessionDataTask *getTokenTask;
@end


@implementation ODBaseAuthProvider

- (instancetype)initWithServiceInfo:(ODServiceInfo *)serviceInfo
                       httpProvider:(id <ODHttpProvider>)httpProvider
                       accountStore:(id <ODAccountStore>)accountStore
                             logger:(id <ODLogger> )logger
{
    self = [super init];
    if (self){
        _serviceInfo = serviceInfo;
        _httpProvider = httpProvider;
        _accountStore = accountStore;
        _logger = logger;
    }
    return self;
}

- (void) authenticateWithViewController:(UIViewController *)viewController completion:(void (^)(NSError *error))completionHandler;
{
    // Get the view controller on the top of the stack
    UIViewController *presentingViewController = [[viewController childViewControllers] firstObject];
    // if the view controller's child is an ODAuthenticationViewController we just want to redirect to a new URL
    // not push another view controller
    if (presentingViewController && [presentingViewController isKindOfClass:[ODAuthenticationViewController class]]){
        self.authViewController = (ODAuthenticationViewController *)presentingViewController;
        NSURL *authURL = [self authURL];
        [self.logger logWithLevel:ODLogDebug message:@"Authentication URL : %@", authURL];
        [self.authViewController redirectWithStartURL:authURL
                                          endURL:[NSURL URLWithString:self.serviceInfo.redirectURL]
                                          success:^(NSURL *endURL, NSError *error){
                                              [self authorizationFlowCompletedWithURL:endURL
                                                                                error:error
                                                             presentingViewController:presentingViewController
                                                                           completion:completionHandler];
                                          }];
    }
    else {
        self.authViewController =
        [[ODAuthenticationViewController alloc] initWithStartURL:[self authURL]
                                                          endURL:[NSURL URLWithString:self.serviceInfo.redirectURL]
                                                         success:^(NSURL *endURL, NSError *error){
                                                             [self authorizationFlowCompletedWithURL:endURL
                                                                                               error:error
                                                                            presentingViewController:self.authViewController
                                                                                          completion:completionHandler];
                                                           
                                                       }];
        dispatch_async(dispatch_get_main_queue(), ^{
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.authViewController];
            navController.modalPresentationStyle = viewController.modalPresentationStyle;
            UIViewController *viewControllerToPresentOn = viewController;
            while (viewControllerToPresentOn.presentedViewController) {
                viewControllerToPresentOn = viewControllerToPresentOn.presentedViewController;
            }
            [viewControllerToPresentOn presentViewController:navController animated:YES  completion:^{
                [self.authViewController loadInitialRequest];
            }];
        });
    }
}

- (void)authorizationFlowCompletedWithURL:(NSURL *)endURL
                                    error:(NSError *)error
                 presentingViewController:(UIViewController *)presentingViewController
                               completion:(AuthCompletion)completionHandler
{
    if (!error){
        [self.logger logWithLevel:ODLogDebug message:@"Response from auth service", endURL];
        NSString *code = [ODAuthHelper codeFromCodeFlowRedirectURL:endURL];
        if (code){
            [self getTokenWithCode:code completion:^(NSError *error) {
                [self dismissAndCompleteAuthorizationWithError:error completion:completionHandler];
            }];
        }
        else{
            [self.logger logWithLevel:ODLogError message:@"Error reading code from response"];
            [self dismissAndCompleteAuthorizationWithError:[self errorFromURL:endURL] completion:completionHandler];
        }
    }
    else{
        [self dismissAndCompleteAuthorizationWithError:error completion:completionHandler];
    }
}

- (void)dismissAndCompleteAuthorizationWithError:(NSError*)error completion:(AuthCompletion)completionHandler {
    ODAuthenticationViewController *authVC = self.authViewController;
    dispatch_async(dispatch_get_main_queue(), ^{
        [authVC dismissViewControllerAnimated:NO completion:nil];
    });
    self.authViewController = nil;
    self.getTokenTask = nil;
    completionHandler(error);
}

- (void)authenticateWithAccountSession:(ODAccountSession *)session completion:(void (^)(NSError *))completionHandler
{
    NSParameterAssert(session);
    
    self.accountSession = session;
    if ([ODAuthHelper shouldRefreshSession:self.accountSession]){
        [self refreshAndStoreAccountSession:session withCompletion:completionHandler];
    }
    else if (completionHandler){
        completionHandler(nil);
    }
}

- (void)refreshAndStoreAccountSession:(ODAccountSession *)session withCompletion:(void (^)(NSError *error))completionHandler
{
    NSParameterAssert(session);
    
    [self refreshSession:session withCompletion:^(ODAccountSession *updatedSession, NSError *error){
        if (updatedSession){
            self.accountSession = updatedSession;
            [self.accountStore storeAccount:updatedSession];
        }
        if (completionHandler){
            completionHandler(error);
        }
    }];
}

- (void)appendAuthHeaders:(NSMutableURLRequest *)request completion:(void (^)(NSMutableURLRequest *requests, NSError *error))completionHandler
{
    NSParameterAssert(completionHandler);
    NSParameterAssert(request);
    
    // Ensure auth provider is ready to append auth headers
    if (!self.accountSession) {
        [self.logger logWithLevel:ODLogError message:@"Auth headers cannot be appended without first successfully authenticating."];
        
        completionHandler(nil, [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODInvalidAccountType userInfo:@{}]);
        return;
    }
    
    NSString *telemtryValue = [NSString stringWithFormat:OD_TELEMTRY_HEADER_VALUE_FORMAT, OD_SDK_VERSION];
    [request setValue:telemtryValue forHTTPHeaderField:self.telemtryHeaderField];
    if([ODAuthHelper shouldRefreshSession:self.accountSession]){
        [self.logger logWithLevel:ODLogDebug message:@"Refreshing session %@", self.accountSession.accountId];
        [self refreshAndStoreAccountSession:self.accountSession withCompletion:^(NSError *error){
            if (!error){
                [ODAuthHelper appendAuthHeaders:request token:self.accountSession.accessToken];
                completionHandler(request, error);
            }
            else{
                completionHandler(nil, error);
            }
        }];
    }
    else{
        [self.logger logWithLevel:ODLogDebug message:@"Appending auth headers without refresh for session: %@", self.accountSession.accountId];
        [ODAuthHelper appendAuthHeaders:request token:self.accountSession.accessToken];
        completionHandler(request, nil);
    }
}

- (void)refreshSession:(ODAccountSession *)session withCompletion:(void (^)(ODAccountSession *updatedSession, NSError *error))completionHandler
{
    NSParameterAssert(session);
    NSParameterAssert(completionHandler);
    
    NSURLRequest *refreshRequest = [self refreshRequestWithRefreshToken:session.refreshToken];
    [[self.httpProvider dataTaskWithRequest:refreshRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        ODAccountSession *updatedSession = [self accountSessionWithData:data response:response error:&error];
        completionHandler(updatedSession, error);
    }] resume];
}

- (void)signOutWithCompletion:(void (^)(NSError *))completionHandler
{
    [self.logger logWithLevel:ODLogDebug message:@"Signing out session: %@", self.accountSession.accountId];
    
    // If we are in the middle of authentication, abort that with code 'canceled'
    if (self.authViewController || self.getTokenTask) {
        if (self.authViewController) {
            [self.authViewController cancel];  // will invoke completion with ODAuthCanceled
        }
        if (self.getTokenTask) {
            [self.getTokenTask cancel];  // will invoke completion with NSURLErrorCancelled
        }
    }
    
    if (self.accountSession) {
        [self.accountStore deleteAccount:self.accountSession];
        self.accountSession = nil;
    }
    
    NSURLRequest *logoutRequest = [self logoutRequest];
    if (logoutRequest){
        [[self.httpProvider dataTaskWithRequest:[self logoutRequest] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            if (completionHandler){
                completionHandler(error);
            }
        }] resume];
    }
    else if (completionHandler){
        completionHandler(nil);
    }
}

- (NSString *)baseURL
{
    return self.serviceInfo.apiEndpoint;
}

- (void)getTokenWithCode:(NSString *)code completion:(AuthCompletion)completion
{
    NSURLRequest *request = [self tokenRequestWithCode:code];
    [self.logger logWithLevel:ODLogDebug message:@"Requesting token with request %@", request];
    self.getTokenTask = [self.httpProvider dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
        if (!error) {
            self.accountSession = [self accountSessionWithData:data response:response error:&error];
            if (self.accountSession.refreshToken){
                [self.accountStore storeCurrentAccount:self.accountSession];
            }
        }
        else if (error.code == NSURLErrorCancelled) {
                error = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODAuthCanceled userInfo:@{}];
        }
        
        if (completion){
            completion(error);
        }
    }];
    [self.getTokenTask resume];
}

- (NSError *)errorFromURL:(NSURL *)url
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (ODAccountSession *)accountSessionWithData:(NSData *)data response:(NSURLResponse *)response error:(NSError * __autoreleasing *)error
{
    ODAccountSession *session = nil;
    if (!*error){
        NSDictionary *responseDictionary = [ODAuthHelper sessionDictionaryWithResponse:response data:data error:error];
        if (responseDictionary){
            session = [ODAuthHelper accountSessionWithResponse:responseDictionary serviceInfo:self.serviceInfo];
        }
    }
    return session;
}

- (NSDictionary *)serviceFlags
{
    return self.serviceInfo.flags;
}

- (NSDictionary *)authRequestParameters
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSURL *)authURL
{
    return [self authRequest].URL;
}

- (NSURLRequest *)authRequest
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSDictionary *)tokenRequestParametersWithCode:(NSString *)code
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSURLRequest *)tokenRequestWithCode:(NSString *)code
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSDictionary *)refreshRequestParametersWithRefreshToken:(NSString *)refreshToken;
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSURLRequest *)tokenRequestWithParameters:(NSDictionary *)params
{
    
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}


- (NSURLRequest *)refreshRequestWithRefreshToken:(NSString *)refreshToken
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSDictionary *)logoutRequestParameters
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

- (NSURLRequest *)logoutRequest
{
    NSAssert(NO, @"Must Implement in base class");
    return nil;
}

@end
