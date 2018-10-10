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
#import "ODModels.h"
#import "ODURLSessionDataTask.h"

@interface ODRequest()

@property NSMutableArray *options;

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      body:(NSData *)body
                                   headers:(NSDictionary *)headers;

@end

@interface ODItemCreateSessionRequest()

@property ODChunkedUploadSessionDescriptor *item;

@end

@implementation ODItemCreateSessionRequest

- (instancetype)initWithItem:(ODChunkedUploadSessionDescriptor *)item URL:(NSURL *)url options:(NSArray *)options client:(ODClient *)client 
{
    self = [super initWithURL:url options:options client:client];
    if (self){
        _item = item;
    }
    return self;
}

- (NSMutableURLRequest *)mutableRequest
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (self.item){
        params[@"item"] = [self.item dictionaryFromItem];
    }

 
    NSData *body = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
    return [self requestWithMethod:@"POST" body:body headers:nil];
}


- (ODURLSessionDataTask *)executeWithCompletion:(void (^)(ODUploadSession *response, NSError *error))completionHandler
{

    ODURLSessionDataTask *task = [self taskWithRequest:self.mutableRequest
                                odObjectWithDictionary:^(NSDictionary *responseObject){
                                                           return [[ODUploadSession alloc] initWithDictionary:responseObject];
                                                       }
                                            completion:completionHandler];
    [task execute];
    return task;
}

@end
