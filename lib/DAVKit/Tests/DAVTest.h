//
//  DAVTest.h
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <DAVKit/DAVKit.h>

#import "DAVTestSettings.h"

@interface DAVTest : SenTestCase < DAVRequestDelegate > {
  @private
	DAVSession *_session;
	BOOL _done;
}

@property (readonly) DAVSession *session;

- (void)notifyDone;
- (void)waitUntilWeAreDone;

@end
