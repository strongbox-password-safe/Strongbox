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

#import "ODNSURLSessionTaskDelegate.h"

@interface ODURLSessionTaskDelegate()

@property (strong, nonatomic) NSProgress *progress;

@property (strong, nonatomic) NSMutableData *mutableData;

@property (strong, nonatomic) NSURL *downloadPath;

@property (strong, nonatomic) ODURLSessionTaskCompletion completion;

@end

@implementation  ODURLSessionTaskDelegate

- (instancetype)initWithProgressRef:(NSProgress * __autoreleasing *)progress
                        completion:(ODURLSessionTaskCompletion)completion
{
    self = [super init];
    if (self){
        if (progress){
            if (!*progress){
                _progress = [NSProgress progressWithTotalUnitCount:0];
                *progress = _progress;
            }
            else{
                _progress = *progress;
            }
        }
        else{
            _progress = nil;
        }
        _mutableData = nil;
        _completion = completion;
    }
    return self;
}


- (void)updateProgressWithBytesSent:(int64_t)sentBytes expectedBytes:(int64_t)expectedByes
{
    NSParameterAssert(sentBytes);
    NSParameterAssert(expectedByes);
    
    if (self.progress){
        if (expectedByes != NSURLSessionTransferSizeUnknown) {
            self.progress.totalUnitCount = expectedByes;
        }
        self.progress.completedUnitCount = sentBytes;
    }
    
}

- (void)didReceiveData:(NSData *)data
{
    if (!self.mutableData){
        self.mutableData = [NSMutableData data];
    }
    [self.mutableData appendData:data];
}

- (void)task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (self.downloadPath && self.completion){
        self.completion(self.downloadPath, task.response, error);
    }
    else if (self.completion){
        self.completion(self.mutableData, task.response, error);
    }
}

- (void)task:(NSURLSessionTask *)task didCompleteDownload:(NSURL *)downloadLocation
{
    self.downloadPath = downloadLocation;
}

@end
