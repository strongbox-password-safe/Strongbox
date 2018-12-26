//
//  FListTest.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "FListTest.h"

@implementation FListTest

- (void)testRequest {
	DAVListingRequest *req = [[DAVListingRequest alloc] initWithPath:@"davkittest"];
	req.delegate = self;
	
	STAssertNotNil(req, @"Couldn't create the request");
	
	[self.session enqueueRequest:req];
	[req release];
	
	[self waitUntilWeAreDone];
}

- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result {
	STAssertTrue([result isKindOfClass:[NSArray class]], @"Expecting a NSArray object for PROPFIND requests");
	STAssertTrue([result count] == 3, @"Array should contain 3 objects");
	
	[self notifyDone];
}

@end
