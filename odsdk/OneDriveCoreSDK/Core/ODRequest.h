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


@class ODClient;

#import <Foundation/Foundation.h>
#import "ODRequestOptionsBuilder.h"
#import "ODAsyncURLSessionDataTask.h"

@class ODObject, ODURLSessionDataTask, ODURLSessionUploadTask;

/**
 The completion handler to be called when the request is finished.
 */
typedef void (^ODObjectCompletionHandler)(id response, NSError *error);

/**
 The block to be called when the requests needs to construct an ODObject from a response dictionary.
 */
typedef id (^ODObjectWithDictionary)(NSDictionary *response);

/**
 An `ODRequest` object is used to make a request to the service.
 */
@interface ODRequest : NSObject

/**
 The client to make the request.
 */
@property (readonly) ODClient *client;

/**
 The URL of the request.
 */
@property (readonly) NSURL *requestURL;

/**
 Creates an `ODRequest` object with the given url and client.
 @param url The url to request from the service.
 @param client The client to make the request.
 */
- (instancetype)initWithURL:(NSURL *)url client:(ODClient *)client;

/**
 Creates an `ODRequest` object with the given url, client, and options.
 @param url The url to request from the service.
 @param options The options for the given request.
 @param client The client to make the request.
 @see ODRequestOptionsBuilder
 */
- (instancetype)initWithURL:(NSURL *)url options:(NSArray *)options client:(ODClient *)client;

/**
 Appends a select option to the request.
 @param select Select string.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) select:(NSString *)select;

/**
 Appends an expand option to the request.
 @param expand Expand string.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) expand:(NSString *)expand;

/**
 Appends an orderBy parameter to the request.
 @param orderBy orderBy string.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) orderBy:(NSString *)orderBy;

/**
 Appends a top parameter to the request.
 @param top The amount of objects in the page.
 @return An ODRequest that represents the same request with the appended options.
*/
- (instancetype) top:(NSInteger)top;

/**
 Appends an ifMatch header to the request.
 @param ifMatch A string of comma separated etags/ctags.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) ifMatch:(NSString *)ifMatch;

/**
 Appends an ifNoneMatch header to the request. 
 @param ifNoneMatch A string of comma separated etags/ctags.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) ifNoneMatch:(NSString *)ifNoneMatch;

/**
 Appends a name conflict parameter to the request.
 @param nameConflict The ODNameConflict object to append to the request.
 @return An ODRequest that represents the same request with the appended options.
 */
- (instancetype) nameConflict:(ODNameConflict *)nameConflict;

/**
 Creates an `ODURLSessionDataTask` with the given request.
 @param The request to create the task with.
 @param castBlock A block that converts an NSDictionary to an ODObject. 
 @param completionHandler The completion handler to be called when the task has finished.
 */
- (ODURLSessionDataTask *)taskWithRequest:(NSMutableURLRequest *)request
                   odObjectWithDictionary:(ODObjectWithDictionary)castBlock
                               completion:(ODObjectCompletionHandler)completionHandler;

/**
 Creates an `ODAsyncURLSessionDataTask` with the given request.
 @param request The request to create the task with.
 @param castBlock A block that converts and NSDictionary into an ODObject.
 @param completionHandler A completion handler to be called when the task is complete and/or when the status has been updated.
 */
- (ODAsyncURLSessionDataTask *)asyncTaskWithRequest:(NSMutableURLRequest *)request
                             odObjectWithDictionary:(ODObjectWithDictionary)castBlock
                                         completion:(ODAsyncActionCompletion)completionHandler;

- (ODURLSessionUploadTask *)uploadTaskWithRequest:(NSMutableURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                           odobjectWithDictionary:(ODObjectWithDictionary)castBlock
                                completionHandler:(ODObjectCompletionHandler)completionHandler;


- (ODURLSessionUploadTask *)uploadTaskWithRequest:(NSMutableURLRequest *)request
                                         fromData:(NSData *)data
                           odobjectWithDictionary:(ODObjectWithDictionary)castBlock
                                completionHandler:(ODObjectCompletionHandler)completionHandler;
@end
