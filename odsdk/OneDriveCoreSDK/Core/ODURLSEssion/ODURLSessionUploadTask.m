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


#import "ODURLSessionUploadTask.h"
#import "ODClient.h"
#import "ODURLSessionTask+Protected.h"
#import "NSJSONSerialization+ResponseHelper.h"

@interface ODURLSessionUploadTask()

@property NSURL *fileURL;

@property NSData *data;

@property (strong) ODUploadCompletionHandler completionHandler;

@end

@implementation ODURLSessionUploadTask

- (instancetype) initWithRequest:(NSMutableURLRequest *)request
                        fromFile:(NSURL *)fileURL
                          client:(ODClient *)client
               completionHandler:(ODUploadCompletionHandler)completionHandler
{
    NSParameterAssert(fileURL);
    
    self = [super initWithRequest:request client:client];
    if(self){
        _fileURL = fileURL;
        _completionHandler = completionHandler;
    }
    return self;
}

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                           data:(NSData *)data
                         client:(ODClient *)client
              completionHandler:(ODUploadCompletionHandler)completionHandler
{
    NSParameterAssert(data);
    
    self = [super initWithRequest:request client:client];
    if (self){
        _data = data;
        _completionHandler = completionHandler;
    }
    return self;
}

-(NSURLSessionUploadTask *)taskWithRequest:(NSMutableURLRequest *)request
{
    NSURLSessionUploadTask *uploadTask = nil;
    NSProgress *progress = self.progress;
    if (self.data){
        uploadTask = [self.client.httpProvider uploadTaskWithRequest:request fromData:self.data progress:&progress completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            [self onCompletion:data response:response error:error];
        }];
    }
    else{
        uploadTask = [self.client.httpProvider uploadTaskWithRequest:request fromFile:self.fileURL progress:&progress completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            [self onCompletion:data response:response error:error];
        }];
    }
    return uploadTask;
}

- (void)onCompletion:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error
{
    _state = ODTaskCompleted;
    NSDictionary *responseDictionary = nil;
    if (!error){
        responseDictionary = [NSJSONSerialization dictionaryWithResponse:response responseData:data error:&error];
    }
    if (error){
        [self.client.logger logWithLevel:ODLogError message:@"Error from download response %@", error];
        if (response){
            [self.client.logger logWithLevel:ODLogDebug message:@"Error from response : %@", response];
        }
    }
    if (self.completionHandler){
        self.completionHandler(responseDictionary, error);
    }
}

- (void)authenticationFailedWithError:(NSError *)authError
{
    self.completionHandler(nil, authError);
}

@end
