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


#import <Foundation/Foundation.h>
#import "ODHttpProvider.h"
#import "ODQueryParameters.h"
#import "ODHeaderOptions.h"

@class ODObject, ODClient;

/**
 The `ODRequestBuilder` constructs `ODRequest` objects from the given url and client.
 @see `ODItemRequestBuilder`
 */
@interface ODRequestBuilder : NSObject

/**
 The client used to create and send the `ODRequest`.
 */
@property (readonly) ODClient *client;

/**
 The url of the request.
 */
@property (readonly) NSURL *requestURL;

/**
 Creates an `ODRequestBuilder` with the given url and client.
 @param url The url of the request.
 @param client The client used to create and send the `ODRequest`.
 */
- (instancetype)initWithURL:(NSURL *)url client:(ODClient *)client;

@end
