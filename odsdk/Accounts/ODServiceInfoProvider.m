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


#import "ODServiceInfoProvider.h"
#import "ODAuthenticationViewController.h"
#import "ODAuthHelper.h"
#import "ODAuthConstants.h"
#import "ODAppConfiguration.h"
#import "ODMSAServiceInfo.h"
#import "ODAADServiceInfo.h"

@interface ODServiceInfoProvider()

@property (strong, nonatomic) ODAppConfiguration *appConfig;

@property (strong, nonatomic) disambiguationCompletion completionHandler;

@end

@implementation ODServiceInfoProvider

- (void)getServiceInfoWithViewController:(UIViewController *)viewController
                        appConfiguration:(ODAppConfiguration *)appConfig
                              completion:(disambiguationCompletion)completionHandler;
{
    NSParameterAssert(viewController);
    NSParameterAssert(appConfig);
    
    self.appConfig = appConfig;
    self.completionHandler = completionHandler;
    
    if (appConfig.microsoftAccountAppId && appConfig.activeDirectoryAppId){
        [self discoverServiceInfoWithViewController:viewController];
    }
    // If we only have a one AppId there is no need to display the disambiguation page we can only select an MSA service info
    else if(appConfig.microsoftAccountAppId){
        ODServiceInfo *serviceInfo = [self serviceInfoWithType:ODMSAAccount appConfig:self.appConfig];
        self.completionHandler(viewController, serviceInfo, nil);
    }
    else if(appConfig.activeDirectoryAppId){
        ODServiceInfo *serviceInfo = [self serviceInfoWithType:ODADAccount appConfig:self.appConfig];
        self.completionHandler(viewController, serviceInfo, nil);
    }
    
}

- (void)discoverServiceInfoWithViewController:(UIViewController *)viewController
{
    NSURL *endURL = [NSURL URLWithString:OD_DISCOVERY_REDIRECT_URL];
    NSURL *startURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@&ru=%@", OD_DISAMBIGUATION_URL, OD_DISCOVERY_REDIRECT_URL]];
    [self.appConfig.logger logWithLevel:ODLogDebug message:@"ServiceInfo provider starting discovery service with URL:", startURL];
        __block ODAuthenticationViewController *discoveryViewController =
        [[ODAuthenticationViewController alloc] initWithStartURL:startURL
                                                          endURL:endURL
                                                         success:^(NSURL *endURL, NSError *error){
                                                             if (!error){
                                                                 [self.appConfig.logger logWithLevel:ODLogDebug message:@"discovered account from response : %@", endURL];
                                                                 ODServiceInfo *serviceInfo = [self serviceInfoFromDiscoveryResponse:endURL appConfig:self.appConfig error:&error];
                                                                 if (error){
                                                                     [self.appConfig.logger logWithLevel:ODLogError message:@"Error parsing authentication service response %@", error];
                                                                 }
                                                                 self.completionHandler(discoveryViewController, serviceInfo, error);
                                                             }
                                                             else {
                                                                 self.completionHandler(discoveryViewController, nil, error);
                                                             }
                                                           }];
    dispatch_async(dispatch_get_main_queue(), ^(){
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:discoveryViewController];
        navController.modalPresentationStyle = viewController.modalPresentationStyle;
        UIViewController *viewControllerToPresentOn = viewController;
        while (viewControllerToPresentOn.presentedViewController) {
            viewControllerToPresentOn = viewControllerToPresentOn.presentedViewController;
        }
        [viewControllerToPresentOn presentViewController:navController animated:YES  completion:^{
            [discoveryViewController loadInitialRequest];
        }];
    });
}

- (ODServiceInfo *)serviceInfoFromDiscoveryResponse:(NSURL *)url appConfig:(ODAppConfiguration *)appConfig error:(NSError * __autoreleasing *)error
{
    NSDictionary *queryParams = [ODAuthHelper decodeQueryParameters:url];
    NSString *accountType = queryParams[OD_DISCOVERY_ACCOUNT_TYPE];
    NSString *userEmail = queryParams[OD_AUTH_USER_EMAIL];
  
    ODServiceInfo *serviceInfo = [self serviceInfoWithString:accountType appConfig:appConfig];
    if (serviceInfo){
        serviceInfo.userEmail = userEmail;
    }
    else {
        if (error){
            *error = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODInvalidAccountType userInfo:@{}];
        }
    }
    return serviceInfo;
}

- (ODServiceInfo *)serviceInfoWithString:(NSString *)accountType appConfig:(ODAppConfiguration *)appConfig
{
    return [self serviceInfoWithType:[self accountTypeFromString:accountType] appConfig:appConfig];
}

- (ODAccountType)accountTypeFromString:(NSString *)accountType
{
    ODAccountType type = ODUnknownAccount;
    if (accountType){
        if ([accountType isEqualToString:OD_DISCOVERY_ACCOUNT_TYPE_MSA]){
            type = ODMSAAccount;
        }
        else if ( [accountType isEqualToString:OD_DISCOVERY_ACCOUNT_TYPE_AAD]){
            type = ODADAccount;
        }
    }
    return type;
}

- (ODServiceInfo *)serviceInfoWithType:(ODAccountType)type appConfig:(ODAppConfiguration *)appConfig
{
    ODServiceInfo *serviceInfo = nil;
    switch (type) {
        case ODADAccount:
            if (appConfig.activeDirectoryAppId){
                NSString *resourceId = appConfig.activeDirectoryResourceId;
                // If we don't know the resourceId we must discover it using the discovery service
                if (!resourceId){
                    resourceId = OD_DISCOVERY_SERVICE_RESOURCEID;
                }
                serviceInfo = [[ODAADServiceInfo alloc] initWithClientId:appConfig.activeDirectoryAppId
                                                              capability:appConfig.activeDirectoryCapability
                                                              resourceId:resourceId
                                                             apiEndpoint:appConfig.activeDirectoryApiEndpointURL
                                                             redirectURL:appConfig.activeDirectoryRedirectURL
                                                                   flags:appConfig.activeDirectoryFlags];
            }
            break;
        case ODMSAAccount:
            if (appConfig.microsoftAccountAppId){
                serviceInfo = [[ODMSAServiceInfo alloc] initWithClientId:appConfig.microsoftAccountAppId
                                                                  scopes:appConfig.microsoftAccountScopes
                                                                   flags:appConfig.microsoftAccountFlags
                                                             apiEndpoint:appConfig.microsoftAccountApiEndpoint];
            }
            break;
        case ODUnknownAccount:
        default : break;
    }
    return serviceInfo;
}

@end
