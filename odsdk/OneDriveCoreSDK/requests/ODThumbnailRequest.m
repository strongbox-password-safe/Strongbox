// Copyright (c) 2015 Microsoft Corporation
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// 
// CodeGen: b53160c326682c5d0326144548f8f1a5297b0f62


//////////////////////////////////////////////////////////////////
// This file was generated and any changes will be overwritten. //
//////////////////////////////////////////////////////////////////



#import "ODODataEntities.h"
#import "ODURLSessionDataTask.h"

@interface ODRequest()

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      body:(NSData *)body 
                                   headers:(NSDictionary *)headers;

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
                                 method:(NSString *)method
                                   body:(NSData *)body 
                                headers:(NSDictionary *)headers;

- (ODURLSessionDataTask*)taskWithRequest:(NSMutableURLRequest *)request
                                completion:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

@end

@implementation ODThumbnailRequest

- (NSMutableURLRequest *)get
{
    return [self requestWithMethod:@"GET"
                              body:nil
                           headers:nil];
}

- (ODURLSessionDataTask *)getWithCompletion:(void (^)(ODThumbnail *response, NSError *error))completionHandler
{
    ODURLSessionDataTask *task = [self taskWithRequest:[self get] 
                                odObjectWithDictionary:^(NSDictionary *response){
                                            return [[ODThumbnail alloc] initWithDictionary:response];
                                        }
                                             completion:completionHandler]; 
    [task execute];
    return task;
}


- (NSMutableURLRequest *)update:(ODThumbnail *)thumbnail
{
    NSData *body = [NSJSONSerialization dataWithJSONObject:[thumbnail dictionaryFromItem] options:0 error:nil];
    return [self requestWithMethod:@"PATCH"
                              body:body
                           headers:nil];
}

- (ODURLSessionDataTask *)update:(ODThumbnail *)thumbnail withCompletion:(void (^)(ODThumbnail *response, NSError *error))completionHandler
{
    ODURLSessionDataTask *task = [self taskWithRequest:[self update:thumbnail] 
                                odObjectWithDictionary:^(NSDictionary *response){
                                            return [[ODThumbnail alloc] initWithDictionary:response];
                                        }
                                              completion:completionHandler];
    [task execute];
    return task;
}

- (NSMutableURLRequest *)delete
{
    return [self requestWithMethod:@"DELETE"
                              body:nil
                           headers:nil];
}

- (ODURLSessionDataTask *)deleteWithCompletion:(void(^)(NSError *error))completionHandler
{
    ODURLSessionDataTask *task = [self taskWithRequest:[self delete] completion:^(NSDictionary *response, NSError *error){
                                                                    completionHandler(error);
                                                                 }];
    [task execute];
    return task;
} 
@end
