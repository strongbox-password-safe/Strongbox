//
//  HibpOperation.m
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UrlRequestOperation.h"

@interface UrlRequestOperation ()

@property (nonatomic, getter = isFinished, readwrite)  BOOL finished;
@property (nonatomic, getter = isExecuting, readwrite) BOOL executing;

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, weak) NSURLSessionTask *task;
@property (nonatomic, copy) void (^dataTaskCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

@end

@implementation UrlRequestOperation

@synthesize finished  = _finished;
@synthesize executing = _executing;

- (instancetype)initWithRequest:(NSURLRequest *)request dataTaskCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))dataTaskCompletionHandler {
    self = [super init];
    if (self) {
        _finished  = NO;
        _executing = NO;

        self.request = request;
        self.dataTaskCompletionHandler = dataTaskCompletionHandler;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url dataTaskCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))dataTaskCompletionHandler {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    return [self initWithRequest:request dataTaskCompletionHandler:dataTaskCompletionHandler];
}

- (void)start {
    if ([self isCancelled]) {
        self.finished = YES;
        return;
    }

    self.executing = YES;

    [self main];
}

- (void)main {
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:self.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        self.dataTaskCompletionHandler(data, response, error);
        [self completeOperation];
    }];

    [task resume];
    self.task = task;
}

- (void)completeOperation {
    self.dataTaskCompletionHandler = nil;
    self.executing = NO;
    self.finished  = YES;
}

- (void)cancel {
    [self.task cancel];
    [super cancel];
}

#pragma mark - NSOperation methods

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isExecuting {
    @synchronized(self) {
        return _executing;
    }
}

- (BOOL)isFinished {
    @synchronized(self) {
        return _finished;
    }
}

- (void)setExecuting:(BOOL)executing {
    @synchronized(self) {
        if (_executing != executing) {
            [self willChangeValueForKey:@"isExecuting"];
            _executing = executing;
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)setFinished:(BOOL)finished {
    @synchronized(self) {
        if (_finished != finished) {
            [self willChangeValueForKey:@"isFinished"];
            _finished = finished;
            [self didChangeValueForKey:@"isFinished"];
        }
    }
}

@end
