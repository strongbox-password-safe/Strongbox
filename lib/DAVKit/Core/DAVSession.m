//
//  DAVSession.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVSession.h"

#import "DAVRequest.h"
#import "DAVRequest+Private.h"
#import "DAVRequests.h"

@implementation DAVSession

@synthesize rootURL = _rootURL;
@synthesize credentials = _credentials;
@synthesize allowUntrustedCertificate = _allowUntrustedCertificate;
@dynamic requestCount, maxConcurrentRequests;

#define DEFAULT_CONCURRENT_REQS 2

- (id)initWithRootURL:(NSURL *)url credentials:(DAVCredentials *)credentials {
	NSParameterAssert(url != nil);
	
	if (!credentials) {
		#ifdef DEBUG
			NSLog(@"Warning: No credentials were provided. Servers rarely grant anonymous access");	
		#endif
	}
	
	self = [super init];
	if (self) {
		_rootURL = [url copy];
		_credentials = credentials;
		_allowUntrustedCertificate = NO;
		
		_queue = [[NSOperationQueue alloc] init];
		[_queue setMaxConcurrentOperationCount:DEFAULT_CONCURRENT_REQS];
		
		[_queue addObserver:self
				 forKeyPath:@"operationCount"
					options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
					context:NULL];
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"operationCount"]) {
		[self willChangeValueForKey:@"requestCount"];
		[self didChangeValueForKey:@"requestCount"];
	}
}

- (NSUInteger)requestCount {
	return [_queue operationCount];
}

- (NSInteger)maxConcurrentRequests {
	return [_queue maxConcurrentOperationCount];
}

- (void)setMaxConcurrentRequests:(NSInteger)aVal {
	[_queue setMaxConcurrentOperationCount:aVal];
}

- (void)enqueueRequest:(DAVBaseRequest *)aRequest {
	NSParameterAssert(aRequest != nil);
	
	aRequest.credentials = _credentials;
	aRequest.rootURL = _rootURL;
	aRequest.allowUntrustedCertificate = _allowUntrustedCertificate;
	
	[_queue addOperation:aRequest];
}

- (void)cancelRequests {
	[_queue cancelAllOperations];
}

- (void)resetCredentialsCache {
	// reset the credentials cache...
	NSDictionary *credentialsDict = [[NSURLCredentialStorage sharedCredentialStorage] allCredentials];
	
	if ([credentialsDict count] > 0) {
		// the credentialsDict has NSURLProtectionSpace objs as keys and dicts of userName => NSURLCredential
		NSEnumerator *protectionSpaceEnumerator = [credentialsDict keyEnumerator];
		id urlProtectionSpace;
		
		// iterate over all NSURLProtectionSpaces
		while ((urlProtectionSpace = [protectionSpaceEnumerator nextObject])) {
			NSEnumerator *userNameEnumerator = [[credentialsDict objectForKey:urlProtectionSpace] keyEnumerator];
			id userName;
			
			// iterate over all usernames for this protection space, which are the keys for the actual NSURLCredentials
			while ((userName = [userNameEnumerator nextObject])) {
				NSURLCredential *cred = [[credentialsDict objectForKey:urlProtectionSpace] objectForKey:userName];
				
				[[NSURLCredentialStorage sharedCredentialStorage] removeCredential:cred
																forProtectionSpace:urlProtectionSpace];
			}
		}
	}
}

- (void)dealloc {
	[_queue removeObserver:self forKeyPath:@"operationCount"];
}

@end
