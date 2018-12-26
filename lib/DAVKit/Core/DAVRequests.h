//
//  DAVRequests.h
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVRequest.h"

@interface DAVCopyRequest : DAVRequest {
  @private
	NSString *_destinationPath;
	BOOL _overwrite;
}

@property (copy) NSString *destinationPath;
@property (assign) BOOL overwrite;

@end

@interface DAVDeleteRequest : DAVRequest { }
@end

@interface DAVGetRequest : DAVRequest { }
@end

@interface DAVListingRequest : DAVRequest {
  @private
	NSUInteger _depth;
}

@property (assign) NSUInteger depth; /* default is 1 */

@end

@interface DAVMakeCollectionRequest : DAVRequest { }
@end

@interface DAVMoveRequest : DAVCopyRequest { }
@end

@interface DAVPutRequest : DAVRequest {
  @private
	NSData *_pdata;
	NSString *_MIMEType;
}

// Pass - [NSData dataWithContentsOfFile:] to upload a local file
@property (strong) NSData *data;
@property (copy) NSString *dataMIMEType; // defaults to application/octet-stream

@end
