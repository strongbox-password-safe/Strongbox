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


#import "ODClient.h"
#import "ODAppConfiguration.h"

/**
 Called when the Authentication has completed.
 */
typedef void (^ODClientAuthenticationCompletion)(ODClient *client, NSError *error);

@interface ODClient (Authentication)

/**
 Reads the current client from the AccountStore.
 @param  appConfig The Application Configuration to retrieve the accountStore object from.
 @return A Client, if one is present.
 @return nil if there is no currently logged in client.
 @see ODAccountStore
 */
+ (ODClient *)currentClientWithAppConfig:(ODAppConfiguration *)appConfig;

/**
 Reads all the clients from the AccountStore (@see ODAccountStoreProtocol.h).
 @param appConfig The Application Configuration to retrieve the accountStore object from.
 */
+ (NSArray *)clientsFromAppConfig:(ODAppConfiguration *)appConfig;

/**
 Creates and authenticates an ODClient object.
 @param appConfig The Application Configuration object to use.
 @param completion The completion handler to be called when the authentication is complete.
        The completion handler will receive an ODClient that has been authenticated, or an NSError if one occurred.
 */
+ (void)authenticatedClientWithAppConfig:(ODAppConfiguration *)appConfig completion:(ODClientAuthenticationCompletion)completion;

/**
 Authenticates the client using an authentication provider. 
 @param  authProvider The Authentication Provider to be used to authenticate the client.
 @param  httpProvider The http provider to handle all http requests.
 @param  logger The logger used to log messages.
 @param  completion The completion handler to be called when authentication is complete.
         error will be nil unless there was an error.
 */
- (void)authenticateWithAuthProvider:(id <ODAuthProvider>)authProvider
                        httpProvider:(id <ODHttpProvider>)httpProvider
                              logger:(id <ODLogger>)logger
                          completion:(void (^)(NSError *error))completion;

/**
 @param  viewController The parent view controller on which to display the authenticationViewController.
 @param  authProvider The Authentication Provider to be used to authenticate the client.
 @param  httpProvider The http provider to handle all http requests.
 @param  logger The logger used to log messages.
 @param  completion The completion handler to be called when authentication is complete.
         error will be nil unless there was an error.
 @see ODAuthenticationViewController
 */
- (void)authenticateWithAuthProvider:(id<ODAuthProvider>)authProvider
                        httpProvider:(id<ODHttpProvider>)httpProvider
                              logger:(id <ODLogger>)logger
                      viewController:(UIViewController *)viewController
                          completion:(void (^)(NSError *))completion;

/**
 Authenticates the client using an application configuration.
 @param  appConfig The Application Configuration object to use.
 @param  completion The completion handler to be called when authentication is complete.
         error will be nil unless there was an error.
 */
- (void)authenticateWithAppConfig:(ODAppConfiguration *)appConfig
                      completion:(void (^)(NSError *error))completion;

@end
