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

@class ODAccountSession;

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^AuthCompletion)(NSError *error);

/**
   The `ODAuthProvider` is a protocol that is used to inject authentication into the ODClient.
   It should handle all initial authentication, refreshing, and appending authentication headers to http requests.
 */
@protocol ODAuthProvider <NSObject>

/**
   The base URL of the service you want to access.
 */
@property (readonly) NSString *baseURL;


/**
  A dictionary of user defined flags, may be nil.
 */
@property (readonly) NSDictionary *serviceFlags;

/**
   Appends the proper authentication headers to the given request.
   @param request The request to append headers to.
   @param completionHandler The completion handler to be called when the auth headers have been appended.
          error should be non nil if there was no error, and should contain any error(s) that occurred.
 */
- (void) appendAuthHeaders:(NSMutableURLRequest *)request completion:(void (^)(NSMutableURLRequest *requests, NSError *error))completionHandler;

@optional
/**
   Authenticates the AuthProvider with UI, where viewController specifies the parent view controller.
   @param viewController The view controller to present the UI on.
   @param completionHandler The completion handler to be called when the authentication has completed.
          error should be non nil if there was no error, and should contain any error(s) that occurred.
 */
- (void) authenticateWithViewController:(UIViewController*)viewController completion:(void (^)(NSError *error))completionHandler;

/**
   Authenticates with a given AccountSession. This method should not invoke any UI.
   @param session The Account Session to authenticate with.
   @param completionHandler The completion handler to be called when the authentication has completed.
          error should be non nil if there was no error, and should contain any error(s) that occurred.
 */
- (void) authenticateWithAccountSession:(ODAccountSession *)session completion:(void (^)(NSError *error))completionHandler;

/**
   Signs out the current AuthProvider.
   @param completionHandler The completion handler to be called when sign out has completed.
          error should be non nil if there was no error, and should contain any error(s) that occurred.
 */
- (void) signOutWithCompletion:(void (^)(NSError *error))completionHandler;

/**
   Gets the current account session.
 */
- (ODAccountSession *)accountSession;

@end
