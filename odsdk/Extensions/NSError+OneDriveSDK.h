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


@class ODError;

#import <Foundation/Foundation.h>

/**
 Helper methods to determine the type of error received.
 ## Usage

 
        [[[[client drive] items:@"foo"] request] getWithCompletion:^(ODItem *response, NSError *error){
             if ([error isClientError]){
                 [self handleClientError:[error clientError]];
             }
             else if ([error isAuthenticationError]){
                 [self handleAuthenticationError:error];
             }
             else {
                 [self handleUnknownError:error]
             }
         }];
 
 */
@interface NSError (OneDriveSDK)

/**
 @return YES if the error was an authentication error.
 @return NO if the error was not an authentication error.
 */
- (BOOL)isAuthenticationError;

/**
 @return YES if the error was caused by a user cancelling the request.
 @return NO if the error was not caused by a user cancelling the request.
 */
- (BOOL)isAuthCanceledError;

/**
 @return YES if the error was a client error.
 @return NO if the error was not a client error.
 */
- (BOOL)isClientError;

/**
 @return The Client error if there was one (see ODError.h).
 @return nil if it was not a client error.
 */
- (ODError *)clientError;

@end

