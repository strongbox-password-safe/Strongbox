//
//  DAVRequestGroup.m
//  DAVKit
//
//  Copyright Matt Rajca 2011. All rights reserved.
//

#import "DAVRequestGroup.h"

@interface DAVRequestGroup ()

- (void)processNextRequest;
- (void)didFinish;

@end


@implementation DAVRequestGroup

- (id)init {
	NSAssert(0, @"The designated initializer -initWithRequests: should be used");
	return nil;
}

- (id)initWithRequests:(NSArray *)requests {
	NSParameterAssert(requests != nil);
	
	self = [super init];
	if (self) {
		_subQueue = [[NSOperationQueue alloc] init];
		[_subQueue setMaxConcurrentOperationCount:1];
		
		_requests = [requests mutableCopy];
	}
	return self;
}

- (BOOL)isConcurrent {
	return YES;
}

- (BOOL)isExecuting {
	return _executing;
}

- (BOOL)isFinished {
	return _done;
}

- (void)start {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(start)
							   withObject:nil
							waitUntilDone:NO];
		
		return;
	}
	
	[self willChangeValueForKey:@"isExecuting"];
	
	_executing = YES;
	
	[self didChangeValueForKey:@"isExecuting"];
	
	[self processNextRequest];
}

- (void)processNextRequest {
	if ([_requests count]) {
		DAVRequest *request = [_requests objectAtIndex:0];
		request.credentials = self.credentials;
		request.rootURL = self.rootURL;
		request.allowUntrustedCertificate = self.allowUntrustedCertificate;
		request.delegate = self;
		
		[_subQueue addOperation:request];
	}
	else {
		[self didFinish];
	}
}

- (void)didFinish {
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"isFinished"];
	
	_done = YES;
	_executing = NO;
	
	[self didChangeValueForKey:@"isExecuting"];
	[self didChangeValueForKey:@"isFinished"];
}

- (void)request:(DAVRequest *)aRequest didFailWithError:(NSError *)error {
	[self didFinish];
}

- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result {
	[_requests removeObject:aRequest];
	
	[self processNextRequest];
}

@end
