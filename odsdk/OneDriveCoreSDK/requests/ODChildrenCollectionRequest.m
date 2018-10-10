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
#import "ODCollection.h"
#import "ODURLSessionDataTask.h"

@interface ODCollectionRequest()

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method 
                                      body:(NSData *)body 
                                   headers:(NSDictionary *)headers;
@end 

@implementation ODChildrenCollectionRequest


- (NSMutableURLRequest *)get
{
    return [self requestWithMethod:@"GET"
                              body:nil
                           headers:nil];
}

- (ODURLSessionDataTask *)getWithCompletion:(ODChildrenCompletionHandler)completionHandler
{

    ODURLSessionDataTask * task = [self collectionTaskWithRequest:[self get]
                                             odObjectWithDictionary:^(NSDictionary *response){
                                            return [[ODItem alloc] initWithDictionary:response];
                                         }
                                                        completion:^(ODCollection *collectionResponse, NSError *error){
                                            if(!error && collectionResponse.nextLink && completionHandler){
                                                ODChildrenCollectionRequest *nextRequest = [[ODChildrenCollectionRequest alloc] initWithURL:collectionResponse.nextLink options:nil client:self.client];
                                                completionHandler(collectionResponse, nextRequest, nil); 
                                            }
                                            else if(completionHandler){
                                                completionHandler(collectionResponse, nil, error);
                                            } 
                                        }];
    [task execute];
    return task;
}

- (NSMutableURLRequest *)addItem:(ODItem*)item
{
    NSData *body = [NSJSONSerialization dataWithJSONObject:[item dictionaryFromItem]
                                                   options:0
                                                     error:nil];
    return [self requestWithMethod:@"POST"
                              body:body
                           headers:nil];

}

- (ODURLSessionDataTask *)addItem:(ODItem*)item withCompletion:(ODItemCompletionHandler)completionHandler
{
    ODURLSessionDataTask *task = [self taskWithRequest:[self addItem:item] 
							     odObjectWithDictionary:^(NSDictionary *response){
                                            return [[ODItem alloc] initWithDictionary:response];
                                        }
                                              completion:completionHandler];
    [task execute];
    return task;
}


@end
