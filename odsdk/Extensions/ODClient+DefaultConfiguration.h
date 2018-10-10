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
#import "ODClient+Authentication.h"
#import "ODAccountStoreProtocol.h"

/**
 ## Default Application Configuration Notes
 @warning When using this category, you must have called one of the setAppId methods (described below) before you create a client object.
 */
@interface ODClient (DefaultConfiguration)

/**
 The account Id of the user.
 */
@property (readonly) NSString *accountId;

/**
 Loads the current client if one exists, if one doesn't it will pop UI and ask for login info.
 @param completion The completion handler to be called when an authenticated client is created.
 @see authenticatedClientWithCompletion: or loadCurrentClient:
 @warning To load a client from disk, you must provide an accountStore. @see ODAccountStoreProtocol.h The default store is the ODAccountStore object.
 @warning This method may invoke the UI. It will present a view controller on the root view controller, unless one is specified in the default app configuration.
 */
+ (void)clientWithCompletion:(ODClientAuthenticationCompletion)completion;

/**
 Creates and authenticates an ODClient object.
 @param completion The completion handler to be called when authentication is completed.
        The completion handler will be called with an ODClient object OR an NSError object. One will always be nil.
 @warning This method may invoke the UI. It will present a view controller on the root view controller, unless one is specified in the default app configuration.
 */
+ (void)authenticatedClientWithCompletion:(ODClientAuthenticationCompletion)completion;

/**
 Sets the OneDrive microsoftAccount app information. @see https://dev.onedrive.com/auth/msa_oauth.htm
 @param  microsoftAccountAppId The application id. Must not be nil.
 @param  microsoftAccountScopes The scopes to be used with authentication. Must not be nil.
 @param  microsoftAccountFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive microsoftAccount authentication flow.
 */
+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
                          scopes:(NSArray *)microsoftAccountScopes
                           flags:(NSDictionary *)microsoftAccountFlags;

/**
 Calls setMicrosoftAccountAppId:scopes:flags: with no flags. @see https://dev.onedrive.com/auth/msa_oauth.htm
 @param  microsoftAccountAppId The application id. Must not be nil.
 @param  microsoftAccountScopes The scopes to be used with authentication. Must not be nil.
 */
+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
                          scopes:(NSArray *)microsoftAccountScopes;



/**
 Calls setActiveDirectoryAppId:capability:redirectURL with OneDrive for business Capability (MyFiles) 
 @param activeDirectoryAppId The applicaiton id. Must not be nil.
 @param redirectURL the redirect url to be used with Azure Active Directory. Most not be nil.
 */
+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                    redirectURL:(NSString *)activeDirectoryRedirectURL;

/**
 Calls setActiveDirectoryAppId:capability:resouceId:apiEndpoint:redirectURL:flags: with the given information.
 @param activeDirectoryAppId The application id. Must not be nil.
 @param redirectURL the direct url to be used with Azure Active Directory. Must not be nil
 */
+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                    redirectURL:(NSString *)activeDirectoryRedirectURL
                          flags:(NSDictionary *)flags;
/**
 Calls setActiveDirectoryAppId:capability:redirectURL:flags: with nil flags.
 @param  activeDirectoryAppId The application id. Must not be nil.
 @param  activeDirectoryCapabilty The capability to use for active directoy. Must not be nil.
 @param  activeDirectoryRedirectURL The redirect url to be used with Azure Active Directory. Must not be nil.
 */
+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     capability:(NSString *)activeDirectoryCapability
                    redirectURL:(NSString *)activeDirectoryRedirectURL;

/**
 Calls setActiveDirectoryAppId:capability:redirectURL:flags: with nil flags.
 @param  activeDirectoryAppId The application id. Must not be nil.
 @param  activeDirectoryResouceId The active directory reosuce id. Must not be nil.
 @param  activeDirectoryApiEndpoint The active directory api endpoint. Must not be nil.
 @param  activeDirectoryRedirectURL The redirect url to be used with Azure Active Directory. Must not be nil.
 */
+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     resourceId:(NSString *)activeDirectoryResourceId
                    apiEndpoint:(NSString *)activeDirectoryApiEndpoint
                    redirectURL:(NSString *)activeDirectoryRedirectURL;

/**
 Sets the OneDrive for Business app information.
 @param  activeDirectoryAppId The application id. Must not be nil.
 @param  activeDirectoryCapability The active directory capability.  Must not be nil if resouceId and apiEndpoint are nil.
 @param  activeDirectoryResouceId The active directroy resouceId.  Must not be nil if capability is nil. 
 @param  activeDirectoryApiEndpoint The active directory ApiEndpoing. Must not be nil if capability is nil.
 @param  activeDirectoryRedirectURL The redirect url to be used with Azure Active Directory. Must not be nil.
 @param  activeDirectoryFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive for Business authentication flow.
 @see https://dev.onedrive.com/auth/aad_oauth.htm
 */
+ (void)setActiveDirectoryAppId:(NSString *)activeDirectoryAppId
                     capability:(NSString *)activeDirectoryCapability
                     resourceId:(NSString *)activeDirectoryResourceId
                    apiEndpoint:(NSString *)activeDirectoryApiEndpoint
                    redirectURL:(NSString *)activeDirectoryRedirectURL
                          flags:(NSDictionary *)activeDirectoryFlags;

/**
 Calls the setActiveDirectoryAppId and setMicrosoftAccountAppId methods to set both microsoftAccount and Business application info.
 @param  microsoftAccountAppId The application id. Must not be nil.
 @param  microsoftAccountScopes The scopes to be used with authentication. Must not be nil.
 @param  microsoftAccountFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive microsoftAccount authentication flow.
 @param  activeDirectoryAppId The application id. Must not be nil.
 @param  activeDirectoryCapabilty The active directroy capability must not be nil
 @param  activeDirectoryRedirectURL The redirect url to be used with Azure Active Directory. Must not be nil.
 @param  activeDirectoryFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive for Business authentication flow.
 */
+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
          microsoftAccountScopes:(NSArray *)microsoftAccountScopes
           microsoftAccountFlags:(NSDictionary *)microsoftAccountFlags
           activeDirectoryAppId:(NSString *)activeDirectoryAppId
       activeDirectoryCapability:(NSString *)activeDirectoryCapability
     activeDirectoryRedirectURL:(NSString *)activeDirectoryRedirectURL
           activeDirectoryFlags:(NSDictionary *)activeDirectoryFlags;
/**
 Calls the setActiveDirectoryAppId and setMicrosoftAccountAppId methods to set both microsoftAccount and Business application info.
 @param  microsoftAccountAppId The application id. Must not be nil.
 @param  microsoftAccountScopes The scopes to be used with authentication. Must not be nil.
 @param  microsoftAccountFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive microsoftAccount authentication flow.
 @param  activeDirectoryAppId The application id. Must not be nil.
 @param  activeDirectoryResouceId The active directroy resource Id. Must not be nil.
 @param  activeDirectoryApiEndpoint The active directroy Api Endpoint. Must not be nil.
 @param  activeDirectoryRedirectURL The redirect url to be used with Azure Active Directory. Must not be nil.
 @param  activeDirectoryFlags A user defined dictionary to be passed through to the client when authenticated using the OneDrive for Business authentication flow.
 */
+ (void)setMicrosoftAccountAppId:(NSString *)microsoftAccountAppId
          microsoftAccountScopes:(NSArray *)microsoftAccountScopes
           microsoftAccountFlags:(NSDictionary *)microsoftAccountFlags
            activeDirectoryAppId:(NSString *)activeDirectoryAppId
       activeDirectoryResourceId:(NSString *)activeDirectoryResourceId
      activeDirectoryApiEndpoint:(NSString *)activeDirectoryApiEndpoint
      activeDirectoryRedirectURL:(NSString *)activeDirectoryRedirectURL
            activeDirectoryFlags:(NSDictionary *)activeDirectoryFlags;
/**
 Sets the authentication provider.
 @param authProvider The auth provider.
 @see ODAuthProvider
 */
+ (void)setAuthProvider:(id <ODAuthProvider>)authProvider;

/**
 Sets the accountStore.
 @param accountStore The accountStore.
 @see ODAccountStoreProtocol
 */
+ (void)setAccountStore:(id <ODAccountStore>)accountStore;

/**
 Sets the httpProvider.
 @see ODHttpProvider
 */
+ (void)setHttpProvider:(id <ODHttpProvider>)httpProvider;

/**
 Sets the parent view controller for the authentication view controller.
 @param parentAuthController The parentViewController to set.
 */
+ (void)setParentAuthController:(UIViewController *)parentAuthController;

/**
 Sets the default logger.
 @param logger The logger to set.
 @see ODLogger
 */
+ (void)setLogger:(id <ODLogger>)logger;

/**
 Loads the current client if there is one.
 @return The current client.
 @return nil if there is no current client.
 @warning You must provide an ODAccountStore to read from by using setAccountStore, if you choose not to use the default store.
 */
+ (ODClient *)loadCurrentClient;

/**
 Sets the current client.
 @param client The client to set.
 */
+ (void)setCurrentClient:(ODClient *)client;

/**
 Loads all of the clients, if they exist.
 @return An array of clients. May be empty if there are no clients.
 @warning You must provide an ODAccountStore to read from by using setAccountStore, if you choose not use the default store.
 */
+ (NSArray *)loadClients;

/**
 Loads the `ODClient` for the given account id.
 */
+ (ODClient *)loadClientWithAccountId:(NSString *)accountId;

/**
 Sets the log level for the clients logger.
 @param level The level of the logger.
 */
- (void)setLogLevel:(ODLogLevel)level;

@end
