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


#import "ODURLSessionTask.h"
#import "ODClient.h"
#import "ODConstants.h"

@interface ODURLSessionTask()

@property (readonly) NSMutableURLRequest *request;

@end

@implementation ODURLSessionTask

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                         client:(ODClient *)client
{
    NSParameterAssert(request);
    NSParameterAssert(client);
    
    self = [super init];
    if (self){
        _client = client;
        _request = request;
        _state = ODTaskCreated;
    }
    return self;
}

- (void)execute;
{
    _state = ODTaskAuthenticating;
    [self.client.authProvider appendAuthHeaders:self.request completion:^(NSMutableURLRequest *request, NSError *error){
        if (self.state != ODTaskCanceled){
            if (!error){
                _state = ODTaskExecuting;
                _innerTask = [self taskWithRequest:request];
                [self.client.logger logWithLevel:ODLogInfo message:@"Created NSURLSessionTask"];
                [self.client.logger logWithLevel:ODLogVerbose message:@"Task Id : %ld", _innerTask.taskIdentifier];
                [_innerTask resume];
            }
            else{
                _state = ODTaskAuthFailed;
                [self.client.logger logWithLevel:ODLogError message:@"Authentication Failed with error :%@", error];
                [self authenticationFailedWithError:error];
            }
        }
    }];
}

- (void)cancel
{
    [self.client.logger logWithLevel:ODLogInfo message:@"Canceled task"];
    if (_innerTask){
        [self.client.logger logWithLevel:ODLogDebug message:@"inner task : %l", [_innerTask taskIdentifier]];
        [_innerTask cancel];
    }
    _state = ODTaskCanceled;
}

- (NSURLSessionTask *)taskWithRequest:(NSMutableURLRequest *)request
{
    NSAssert(NO, @"Not Implemented, must implement in sub class");
    return nil;
}

- (void)authenticationFailedWithError:(NSError *)authError
{
    NSAssert(NO, @"Not Implemented, must implement in sub class");
}

@end
