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
@class ODAppConfiguration, ODServiceInfo;

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 A completion handler to be called when the discovery service has completed.
 */
typedef void(^disambiguationCompletion)(UIViewController *presentedDiscoveryController, ODServiceInfo *serviceInfo, NSError *error);

/**
 The `ODServiceInfoProvider` provides the correct service info to use. It will invoke the UI to prompt the user for their email.
 */
@interface ODServiceInfoProvider : NSObject <UIWebViewDelegate>

/**
 Starts the discovery service flow to discover the correct service info object to use.
 @param viewController The provider will Invoke the UI to prompt the user for their email. This is the parent view controller to present the UI on.
 @param appConfig The app configuration for this application.
 @param completionHandler A disambiguationCompletion handler that will be called when the discovery service has completed.
 */
- (void)getServiceInfoWithViewController:(UIViewController *)viewController
                        appConfiguration:(ODAppConfiguration *)appConfig
                              completion:(disambiguationCompletion)completionHandler;

@end
