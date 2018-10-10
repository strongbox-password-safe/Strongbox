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
@class ODCollection;

#import "ODRequest.h"

/**
 An `ODRequest` that is used to make collection requests from the service.
 */
@interface ODCollectionRequest : ODRequest

/**
 Creates an `ODURLSessionDataTask` with the given requests.
 @param request The request to create the task with.
 @param castBlock A block that will convert a response dictionary to an `ODCollection`.
 @param completionHandler The completion handler to be called when the request is complete.
 */
- (ODURLSessionDataTask *)collectionTaskWithRequest:(NSMutableURLRequest *)request
                             odObjectWithDictionary:(ODObject* (^)(NSDictionary *response))castBlock
                                         completion:(void (^)(ODCollection *response, NSError *error))completionHandler;

@end
