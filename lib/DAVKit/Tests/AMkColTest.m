//
//  AMkColTest.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "AMkColTest.h"

@implementation AMkColTest

- (void)testRequest {
	DAVMakeCollectionRequest *req = [[DAVMakeCollectionRequest alloc] initWithPath:@"davkittest"];
	req.delegate = self;
	
	STAssertNotNil(req, @"Couldn't create the request");
	
	[self.session enqueueRequest:req];
	[req release];
	
	[self waitUntilWeAreDone];
}

- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result {
	STAssertNil(result, @"No result expected for MKCOL");
	
	[self notifyDone];
}

@end
