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


#import "ODURLSessionDownloadTask.h"
#import "ODClient.h"
#import "ODURLSessionTask+Protected.h"
#import "NSJSONSerialization+ResponseHelper.h"
#import "ODConstants.h"

@interface ODURLSessionDownloadTask()

@property (strong) ODDownloadCompletionHandler completionHandler;

@end

@implementation ODURLSessionDownloadTask

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                         client:(ODClient *)client
             completionHandler:(ODDownloadCompletionHandler)completionHandler
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
        self.completionHandler(nil, nil, authError);
    }
}

- (NSURLSessionDownloadTask *)taskWithRequest:(NSMutableURLRequest *)request
{
    [self.client.logger logWithLevel:ODLogVerbose message:@"Creating download task with request : %@", request];
    NSProgress *progress = self.progress;
    return [self.client.httpProvider downloadTaskWithRequest:request progress:&progress completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error){
        _state = ODTaskCompleted;
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        [self.client.logger logWithLevel:ODLogVerbose message:@"Received download response with http status code %ld", statusCode];
        if (!error && statusCode != ODOK && statusCode != ODPartialContent) {
            // The only responses that should allow for the binary data to be in the file are a 200
            // (for all file content downloaded successfully) or a 206 (for the requested file range
            // downloaded successfully), otherwise it will be empty (304 no body)
            // or contain the error json blob which will be passed back in the error object if it exists
            // because this is a download task it will download the response to disk instead of memory
            if ( statusCode != ODNotModified){
                error = [self readErrorFromFile:location response:response];
            }
            location = nil;
        }
        if (self.completionHandler){
            self.completionHandler(location, response, error);
        }
    }];
}

- (NSError *)readErrorFromFile:(NSURL *)fileLocation response:(NSURLResponse *)response
{
    NSError *error = nil;
    NSData *responseData = [NSData dataWithContentsOfURL:fileLocation options:0 error:&error];
    if (error){
        [self.client.logger logWithLevel:ODLogWarn message:@"Failed to read error from file"];
        [self.client.logger logWithLevel:ODLogDebug message:@"File read error : %@", responseData];
        // if we can't read the error form disk thats ok just created a malformed error down the line
        error = nil;
    }
    NSDictionary *responseObject = nil;
    if (responseData){
        responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        if (error){
            [self.client.logger logWithLevel:ODLogWarn message:@"Error parsing error : %@", error];
        }
    }
    // If we couldn't parse the error object from the file still return an error with the proper code and no ODError
    return [NSJSONSerialization errorFromResponse:response responseObject:responseObject];
}

@end
