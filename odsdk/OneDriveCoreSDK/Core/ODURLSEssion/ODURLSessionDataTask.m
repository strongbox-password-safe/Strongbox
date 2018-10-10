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


#import "ODURLSessionDataTask.h"
#import "ODURLSessionTask+Protected.h"
#import "ODClient.h"
#import "NSJSONSerialization+ResponseHelper.h"

@interface ODURLSessionDataTask()

@property (strong) void (^completionHandler)(NSDictionary *dictionary, NSError *error);

@end

@implementation ODURLSessionDataTask

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                         client:(ODClient *)client
                     completion:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler
{
    self = [super initWithRequest:request client:client];
    if (self){
        _completionHandler = completionHandler;
    }
    return self;
}

- (void)authenticationFailedWithError:(NSError *)authError
{
    if (self.completionHandler){
        self.completionHandler(nil, authError);
    }
}

- (NSURLSessionDataTask *)taskWithRequest:(NSMutableURLRequest *)request
{
    NSParameterAssert(request);
    
    if (![request.HTTPMethod isEqualToString:@"GET"]){
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    return [self.client.httpProvider dataTaskWithRequest:request
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
                                      
       _state = ODTaskCompleted;
       NSError *resolvedError = nil;
       NSDictionary *resolvedResponse = nil;
        if (!error && response){
            resolvedResponse = [NSJSONSerialization dictionaryWithResponse:response responseData:data error:&resolvedError];
        }
        else {
            resolvedError = error;
        }
        if (self.completionHandler){
            self.completionHandler(resolvedResponse, resolvedError);
        }
    }];
}

@end
