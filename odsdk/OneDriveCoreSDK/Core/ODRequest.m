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


#import "ODRequest.h"
#import "ODHeaderOptions.h"
#import "ODURLSessionDataTask.h"
#import "ODURLSessionUploadTask.h"
#import "ODClient.h"
#import "ODConstants.h"

@interface ODRequest()

@property NSMutableArray *options;

@end


@implementation ODRequest

- (instancetype) select:(NSString *)select
{
    [self.options addObject:[ODSelectOptions select:select]];
    return self;
}

- (instancetype) expand:(NSString *)expand
{
    [self.options addObject:[ODExpandOptions expand:expand]];
    return self;
}

- (instancetype) orderBy:(NSString *)orderBy
{
    [self.options addObject:[ODOrderByOptions orderBy:orderBy]];
    return self;
}

- (instancetype) top:(NSInteger)top
{
    [self.options addObject:[ODTopOptions top:top]];
    return self;
}

- (instancetype) ifMatch:(NSString *)ifMatch
{
    [self.options addObject:[ODIfMatch entityTags:ifMatch]];
    return self;
}

- (instancetype) ifNoneMatch:(NSString *)ifNoneMatch
{
    [self.options addObject:[ODIfNoneMatch entityTags:ifNoneMatch]];
    return self;
}

- (instancetype) nameConflict:(ODNameConflict *)nameConflict
{
    [self.options addObject:nameConflict];
    return self;
}

- (instancetype)initWithURL:(NSURL *)url client:(ODClient *)client
{
    return [self initWithURL:url options:nil client:client];
}

- (instancetype) initWithURL:(NSURL *)url options:(NSArray *)options client:(ODClient *)client
{
    NSParameterAssert(url);
    NSParameterAssert(client);
    
    [client.logger logWithLevel:ODLogDebug message:@" ODRequest init with URL : %@ options : %@", url, options];
    self = [super init];
    if (self){
        // It may be best to make this an options object so it is type safe
        if (options){
            [options enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                if (![obj isKindOfClass:[ODRequestOptions class]]){
                    [client.logger logWithLevel:ODLogError message:@" Option : %@ are not ODRequestOptions", obj];
                    NSAssert([obj isKindOfClass:[ODRequestOptions class]], @"Options must be of type ODRequestOptions");
                }
            }];
        }
        _options = [options mutableCopy];
        if (!_options){
            _options = [NSMutableArray array];
        }
        _requestURL =  url;
        _client = client;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      body:(NSData *)body
                                   headers:(NSDictionary *)headers
{
    NSParameterAssert(method);
    
    [self.client.logger logWithLevel:ODLogVerbose message:@" Creating Request with method : %@ body : %@ headers : %@", method, body, headers];
    
    ODRequestOptionsBuilder *optionsBuilder = [ODRequestOptionsBuilder optionsWithArray:self.options];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",[self.requestURL absoluteString], optionsBuilder.queryOptions]];
   
    [self.client.logger logWithLevel:ODLogDebug message:@"Request url : %@", url];
    
    // Apple tries to be smart but they are using the wrong eTag when making requests...
    // so we must disable the caching policy
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:60];
    request.HTTPMethod = method;

    if (body){
        request.HTTPBody = body;
    }
    if (headers && [headers count] > 0){
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL*stop){
            [request setValue:value forHTTPHeaderField:key];
        }];
    }
    [optionsBuilder.headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop){
        [request setValue:value forHTTPHeaderField:key];
    }];
    return request;
}

- (ODURLSessionDataTask *)taskWithRequest:(NSMutableURLRequest *)request
                   odObjectWithDictionary:(ODObjectWithDictionary)castBlock
                               completion:(ODObjectCompletionHandler)completionHandler
{
    NSParameterAssert(request);
    
    [self.client.logger logWithLevel:ODLogVerbose message:@"Creating Data task with request : %@", request];
    
    return [self taskWithRequest:request completion:^(NSDictionary *rawResponse, NSError *error){
        if (!error){
            if (completionHandler && castBlock){
                id parsedObject = castBlock(rawResponse);
                completionHandler(parsedObject, nil);
            }
        }
        else {
            [self.client.logger logWithLevel:ODLogError message:@"Error from data task : %@", error];
            [self.client.logger logWithLevel:ODLogError message:@"Caused by request %@", request];
            if(completionHandler){
                completionHandler(nil, error);
            }
        }
    }];
}

- (ODAsyncURLSessionDataTask *)asyncTaskWithRequest:(NSMutableURLRequest *)request
                             odObjectWithDictionary:(ODObjectWithDictionary)castBlock
                                        completion:(ODAsyncActionCompletion)completionHandler
{
    NSParameterAssert(request);
    
    ODAsyncActionCompletion asyncCompletion = nil;
    [self.client.logger logWithLevel:ODLogVerbose message:@"Creating Async task with request : %@", request];
    if (completionHandler){
        asyncCompletion = ^(NSDictionary *response, ODAsyncOperationStatus *status, NSError *error){
            if (!error){
                // if we have the completionHandler and cast blocks as well as no status
                if (completionHandler && castBlock){
                    id parsedObject = nil;
                    if (!status){
                        parsedObject = castBlock(response);
                    }
                    completionHandler(parsedObject, status, error);
                }
            }
            else {
                [self.client.logger logWithLevel:ODLogError message:@"Error from async task : %@", error];
                [self.client.logger logWithLevel:ODLogDebug message:@"Caused by request %@", request];
                if(completionHandler){
                    completionHandler(nil, status, error);
                }
            }
        };
    }
    return [self asyncTaskWithRequest:request completion:asyncCompletion];
}

- (ODURLSessionUploadTask *)uploadTaskWithRequest:(NSMutableURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                           odobjectWithDictionary:(ODObjectWithDictionary)castBlock
                                completionHandler:(ODObjectCompletionHandler)completionHandler
{
    [self.client.logger logWithLevel:ODLogVerbose message:@"Creating upload task with requests : %@", request];
    return [[ODURLSessionUploadTask alloc] initWithRequest:request
                                                  fromFile:fileURL
                                                    client:self.client
                                         completionHandler:^(NSDictionary *response, NSError *error){
                                             [self onUploadCompletion:response
                                                                error:error
                                                odObjectWithDictionar:castBlock
                                                    completionHandler:completionHandler];
    }];
}

- (ODURLSessionUploadTask *)uploadTaskWithRequest:(NSMutableURLRequest *)request
                                         fromData:(NSData *)data
                           odobjectWithDictionary:(ODObjectWithDictionary)castBlock
                                completionHandler:(ODObjectCompletionHandler)completionHandler
{
     [self.client.logger logWithLevel:ODLogVerbose message:@"Creating upload task with requests : %@", request];
    return [[ODURLSessionUploadTask alloc] initWithRequest:request
                                                    data:data
                                                    client:self.client
                                         completionHandler:^(NSDictionary *response, NSError *error){
                                             [self onUploadCompletion:response
                                                                error:error
                                                odObjectWithDictionar:castBlock
                                                    completionHandler:completionHandler];
    }]; 
}

- (void)onUploadCompletion:(NSDictionary *)response
                     error:(NSError *)error
     odObjectWithDictionar:(ODObjectWithDictionary)castBlock
         completionHandler:(ODObjectCompletionHandler)completionHandler
{
    if (completionHandler){
    id parsedObject = nil;
        if (!error && castBlock){
            parsedObject = castBlock(response);
        }
        completionHandler(parsedObject, error);
    }
}

- (ODAsyncURLSessionDataTask *)asyncTaskWithRequest:(NSMutableURLRequest *)request
                                         completion:(ODAsyncActionCompletion)completionHandler
{
    NSParameterAssert(request);
    
    return [[ODAsyncURLSessionDataTask alloc] initWithRequest:request client:self.client completion:completionHandler];
}

- (ODURLSessionDataTask *)taskWithRequest:(NSMutableURLRequest *)request
                               completion:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler
{
    NSParameterAssert(request);
    
    return [[ODURLSessionDataTask alloc] initWithRequest:request client:self.client completion:completionHandler];
    
}

@end
