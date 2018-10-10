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

#import "ODURLSessionManager.h"
#import "ODNSURLSessionTaskDelegate.h"

@interface ODURLSessionManager()

@property (strong, nonatomic) NSURLSessionConfiguration *urlSessionConfiguration;

@property (strong, nonatomic) NSURLSession *urlSession;

@property (strong, nonatomic) NSMutableDictionary *taskDelegates;

@end

@implementation ODURLSessionManager

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)urlSessionConfiguration
{
    self = [super init];
    if (self){
        _urlSessionConfiguration = urlSessionConfiguration;
        _urlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration delegate:self delegateQueue:nil];
        _taskDelegates = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(ODDataCompletionHandler)completionHandler;
{
    NSURLSessionDataTask *dataTask = nil;
    @synchronized(self.urlSession){
        dataTask = [self.urlSession dataTaskWithRequest:request];
    }
    
    [self addDelegateForTask:dataTask withProgress:nil completion:completionHandler];
    return dataTask;
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request progress:(NSProgress * __autoreleasing *)progress completionHandler:(ODRawDownloadCompletionHandler)completionHandler
{
    NSURLSessionDownloadTask *downloadTask = nil;
    @synchronized(self.urlSession){
        downloadTask = [self.urlSession downloadTaskWithRequest:request];
    }
    [self addDelegateForTask:downloadTask withProgress:progress completion:completionHandler];
    
    return downloadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)data
                                         progress:(NSProgress * __autoreleasing *)progress
                                completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    NSURLSessionUploadTask *uploadTask = nil;
    @synchronized(self.urlSession){
        uploadTask = [self.urlSession uploadTaskWithRequest:request fromData:data];
    }
    [self addDelegateForTask:uploadTask withProgress:progress completion:completionHandler];
    
    return uploadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                                         progress:(NSProgress * __autoreleasing *)progress
                                completionHandler:(ODRawUploadCompletionHandler)completionHandler
{
    NSURLSessionUploadTask *uploadTask = nil;
    @synchronized(self.urlSession){
        uploadTask = [self.urlSession uploadTaskWithRequest:request fromFile:fileURL];
    }
    
    [self addDelegateForTask:uploadTask withProgress:progress completion:completionHandler];
    
    return uploadTask;
}

- (void)addDelegateForTask:(NSURLSessionTask *)task
              withProgress:(NSProgress * __autoreleasing *)progress
                completion:(ODURLSessionTaskCompletion)completion
{
    ODURLSessionTaskDelegate *delegate = [[ODURLSessionTaskDelegate alloc]
                                           initWithProgressRef:progress
                                           completion:completion];
    @synchronized(self.taskDelegates){
        self.taskDelegates[@(task.taskIdentifier)] = delegate;
    }
}

- (ODURLSessionTaskDelegate*)getDelegateForTask:(NSURLSessionTask *)task
{
    ODURLSessionTaskDelegate *delegate = nil;
    @synchronized(self.taskDelegates){
        delegate = self.taskDelegates[@(task.taskIdentifier)];
    }
    return delegate;
}

- (void)removeTaskDelegateForTask:(NSURLSessionTask *)task
{
    @synchronized(self.taskDelegates){
        [self.taskDelegates removeObjectForKey:@(task.taskIdentifier)];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    ODURLSessionTaskDelegate *delegate = [self getDelegateForTask:task];
    
    if (delegate){
        [delegate task:task didCompleteWithError:error];
    }
    [self removeTaskDelegateForTask:task];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data
{
    ODURLSessionTaskDelegate *delegate = [self getDelegateForTask:dataTask];
    
    if (delegate){
        [delegate didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didSendBodyData:(int64_t)bytesSent
                                 totalBytesSent:(int64_t)totalBytesSent
                       totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    ODURLSessionTaskDelegate *delegate = [self getDelegateForTask:task];
    
    if (delegate){
        [delegate updateProgressWithBytesSent:totalBytesSent expectedBytes:totalBytesExpectedToSend];
    }
}


- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    ODURLSessionTaskDelegate *delegate = [self getDelegateForTask:downloadTask];
    
    if (delegate){
        [delegate updateProgressWithBytesSent:totalBytesWritten expectedBytes:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    ODURLSessionTaskDelegate *delegate = [self getDelegateForTask:downloadTask];
    
    if (delegate) {
        [delegate task:downloadTask didCompleteDownload:location];
        [delegate task:downloadTask didCompleteWithError:nil];
        // remove the task now so we don't call the completion handler when the completion delegate method gets called
        [self removeTaskDelegateForTask:downloadTask];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)redirectResponse
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSMutableURLRequest *newRequest = nil;
    if (request){
        newRequest = [request mutableCopy];
        [task.originalRequest.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
            [newRequest setValue:value forHTTPHeaderField:key];
        }];
    }
    completionHandler(newRequest);
}

@end
