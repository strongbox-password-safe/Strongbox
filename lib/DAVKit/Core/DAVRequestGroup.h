//
//  DAVRequestGroup.h
//  DAVKit
//
//  Copyright Matt Rajca 2011. All rights reserved.
//

#import "DAVBaseRequest.h"
#import "DAVRequest.h"

@interface DAVRequestGroup : DAVBaseRequest < DAVRequestDelegate > {
  @private
	NSOperationQueue *_subQueue;
	NSMutableArray *_requests;
	BOOL _done, _executing;
}

/* The requests are executed serially; if one fails the remaining ones 
   are cancelled */

- (id)initWithRequests:(NSArray *)requests;

@end
