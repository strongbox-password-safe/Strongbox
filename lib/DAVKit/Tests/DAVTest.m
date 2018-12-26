//
//  DAVTest.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVTest.h"

@implementation DAVTest

@synthesize session = _session;

- (void)setUp {
	_done = NO;
	
	DAVCredentials *credentials = [DAVCredentials credentialsWithUsername:USERNAME
																 password:PASSWORD];
	
	STAssertNotNil(credentials, @"Couldn't create credentials");
	STAssertTrue([USERNAME isEqualToString:credentials.username], @"Couldn't set username");
	STAssertTrue([PASSWORD isEqualToString:credentials.password], @"Couldn't set password");
	
	NSURL *host = [NSURL URLWithString:HOST];
	
	_session = [[DAVSession alloc] initWithRootURL:host credentials:credentials];
	STAssertNotNil(_session, @"Couldn't create DAV session");
	
	_session.maxConcurrentRequests = 1;
}

- (void)notifyDone {
	_done = YES;
}

- (void)waitUntilWeAreDone {
	while (!_done) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
}

- (void)request:(DAVRequest *)aRequest didFailWithError:(NSError *)error {
	STFail(@"We have an error: %@", error);
	
	[self notifyDone];
}

- (void)tearDown {
	[_session release];
	_session = nil;
}

@end
