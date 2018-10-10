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


#import "ODBusinessAuthProvider.h"
#import <ADAL/ADAuthenticationContext.h>
#import "ODServiceInfo.h"
#import "ODAuthProvider+Protected.h"
#import "ODAuthHelper.h"
#import "ODAuthConstants.h"
#import "ODAccountSession.h"
#import "ODAuthenticationViewController.h"

@interface ODBusinessAuthProvider(){
    @private
    ADAuthenticationContext *_authContext;
}

@end

@implementation ODBusinessAuthProvider

- (void) authenticateWithViewController:(UIViewController*)viewController completion:(void (^)(NSError *error))completionHandler
{
    self.authContext.parentController = viewController;
    // If the disambiguation page is still being displayed remove it from the view
    if (self.authContext.parentController){
        UIViewController *childViewController = [[viewController childViewControllers] firstObject];
        if (childViewController && [childViewController respondsToSelector:@selector(redirectWithStartURL:endURL:success:)]){
            self.authContext.parentController = viewController.presentingViewController;
           dispatch_async(dispatch_get_main_queue(), ^{
               [childViewController dismissViewControllerAnimated:NO completion:nil];
           });
       }
    }
    [self.authContext acquireTokenWithResource:self.serviceInfo.resourceId
                                      clientId:self.serviceInfo.appId
                                   redirectUri:[NSURL URLWithString:self.serviceInfo.redirectURL]
                                promptBehavior:AD_PROMPT_ALWAYS
                                        userId:self.serviceInfo.userEmail
                          extraQueryParameters:nil
                               completionBlock:^(ADAuthenticationResult *result){
                              if (result.status == AD_SUCCEEDED){
                                  // If the resourceId being used is for the discovery service
                                  if ([self.serviceInfo.discoveryServiceURL containsString:self.serviceInfo.resourceId]){
                                      // Find the resourceIds needed
                                      [self discoverResourceWithAuthResult:result completion:^(ODServiceInfo *serviceInfo, NSError *error){
                                          //Refresh the token with the correct resource Ids
                                          if (!error){
                                              self.serviceInfo = serviceInfo;
                                          }
                                          if (!self.serviceInfo.apiEndpoint){
                                              NSError *apiEndpointError = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN
                                                                                              code:ODServiceError
                                                                                          userInfo:@{
                                                                                                     NSLocalizedDescriptionKey : @"There was a problem logging you in",
                                                                                                     OD_AUTH_ERROR_KEY : @"Could not discover the api endpoint for the given user.  Make sure you have correctly enabled the SharePoint files permissions in Azure portal."
                                                                                                    }];
                                              completionHandler(apiEndpointError);
                                          }
                                          else if (result.tokenCacheStoreItem.refreshToken){
                                              [self.authContext acquireTokenByRefreshToken:result.tokenCacheStoreItem.refreshToken clientId:self.serviceInfo.appId resource:self.serviceInfo.resourceId completionBlock:^(ADAuthenticationResult *innerResult){
                                                  if (innerResult.status == AD_SUCCEEDED) {
                                                      innerResult.tokenCacheStoreItem.userInformation = result.tokenCacheStoreItem.userInformation;
                                                      
                                                      [self setAccountSessionWithAuthResult:innerResult];
                                                      completionHandler(nil);
                                                  }
                                                  else {
                                                      completionHandler(innerResult.error);
                                                  }
                                              }];
                                          }
                                          else {
                                              NSError *noRefreshTokenError = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN
                                                                                                 code:ODServiceError
                                                                                             userInfo:@{
                                                                                                        NSLocalizedDescriptionKey : @"There was a problem logging you in",
                                                                                                        OD_AUTH_ERROR_KEY : @" The auth result must have a refresh token" }];
                                              completionHandler(noRefreshTokenError);
                                          }
                                      }];
                                  }
                                  else {
                                      [self setAccountSessionWithAuthResult:result];
                                      completionHandler(nil);
                                  }
                              }
                              else {
                                  completionHandler(result.error);
                              }
    }];
}

- (void)setAccountSessionWithAuthResult:(ADAuthenticationResult *)result
{
    self.accountSession = [[ODAccountSession alloc] initWithId:result.tokenCacheStoreItem.userInformation.userId
                                                   accessToken:result.tokenCacheStoreItem.accessToken
                                                       expires:result.tokenCacheStoreItem.expiresOn
                                                  refreshToken:result.tokenCacheStoreItem.refreshToken
                                                   serviceInfo:self.serviceInfo];
    if (self.accountSession.refreshToken){
        [self.accountStore storeCurrentAccount:self.accountSession];
    }
}

-(void)discoverResourceWithAuthResult:(ADAuthenticationResult *)result completion:(void (^)(ODServiceInfo *, NSError *))completion
{
    NSMutableURLRequest *discoveryRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.serviceInfo.discoveryServiceURL]];
    [ODAuthHelper appendAuthHeaders:discoveryRequest token:result.accessToken];
    [[self.httpProvider dataTaskWithRequest:discoveryRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
       if (!error){
           NSDictionary *responseObject = [ODAuthHelper sessionDictionaryWithResponse:response data:data error:&error];
           if (responseObject){
               [self setServiceInfo:self.serviceInfo withCapability:self.serviceInfo.capability discoveryResponse:responseObject];
           }
           completion(self.serviceInfo, error);
        }
       else{
           completion(nil, error);
       }
    }] resume];
}

- (void)setServiceInfo:(ODServiceInfo *)serviceInfo withCapability:(NSString *)capability discoveryResponse:(NSDictionary *)discoveryResponse
{
    NSArray *values = discoveryResponse[@"value"];
    [values enumerateObjectsUsingBlock:^(NSDictionary *serviceResponse, NSUInteger index, BOOL *stop){
        if ([serviceResponse[@"capability"] isEqualToString:capability]){
            serviceInfo.resourceId = serviceResponse[@"serviceResourceId"];
            serviceInfo.apiEndpoint = serviceResponse[@"serviceEndpointUri"];
        }
    }];
}

- (void)refreshSession:(ODAccountSession *)session withCompletion:(void (^)(ODAccountSession *updatedSession, NSError *error))completionHandler
{
    [self.authContext acquireTokenByRefreshToken:session.refreshToken
                                        clientId:self.serviceInfo.appId
                                        resource:self.serviceInfo.resourceId
                                 completionBlock:^(ADAuthenticationResult *authResult){
                                     if (authResult.status == AD_SUCCEEDED){
                                         session.accessToken = authResult.accessToken;
                                         session.refreshToken = authResult.tokenCacheStoreItem.refreshToken;
                                         session.expires = authResult.tokenCacheStoreItem.expiresOn;
                                         completionHandler(session, nil);
                                     }
                                     else {
                                         completionHandler(nil, authResult.error);
                                     }
    }];
}

- (NSString*)telemtryHeaderField
{
    return [OD_AAD_TELEMTRY_HEADER copy];
}

- (ADAuthenticationContext *)authContext
{
    if (!_authContext){
        _authContext = [ADAuthenticationContext authenticationContextWithAuthority:self.serviceInfo.authorityURL error:nil];
    }
    return _authContext;
}

- (NSURLRequest*)logoutRequest
{
    return nil;
}

@end
