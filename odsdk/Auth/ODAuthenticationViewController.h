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

#import <UIKit/UIKit.h>

typedef void (^ODEndURLCompletion)(NSURL *endURL, NSError *error);

/**
 This View Controller is used for OAuth flow.
 It will load the startURL and follow all redirects and web requests until it reaches the endURL.
 It will call the success completion handler if it reaches the endURL or there was an error. 
 If the user cancels, the error will be a user canceled error.
 */
@interface ODAuthenticationViewController : UIViewController

/**
 Starts the OAuth flow.
 @param  startURL The URL for web view.
 @param  endURL Once this URL is reached the completion handler will be called.
 @param  successCompletion The completion handler to call when the endURL is reached or there was an error.
 */
- (instancetype)initWithStartURL:(NSURL *)startURL
                          endURL:(NSURL *)endURL
                         success:(ODEndURLCompletion)successCompletion;

/**
 Redirects the current view to the startURL.
 @param  startURL The URL for the redirect request.
 @param  endURL Once this URL is reached, the completion handler will be called.
 @param  successCompletion The completion handler to be called once the flow is complete or there was an error.
 @see initWithStartURL:endURL:success:
 */
- (void)redirectWithStartURL:(NSURL *)startURL
                      endURL:(NSURL *)endURL
                      success:(ODEndURLCompletion)successCompletion;

/**
 Loads the initial request created from startURL.
 @see initWithStartURL:endURL:success:
 */
- (void)loadInitialRequest;

/**
 Aborts the OAuth flow. If the auth flow has already completed this is a no-op,
   otherwise the success completion will be called with code ODAuthCanceled.
 */
- (void)cancel;

@property (nonatomic) NSTimeInterval requestTimeout;

@end
