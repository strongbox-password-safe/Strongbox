//
//  DAVBaseRequest.h
//  DAVKit
//
//  Copyright Matt Rajca 2011. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^DAVCompletionBlock)(BOOL success, id result, NSError *error);

@class DAVCredentials;

@interface DAVBaseRequest : NSOperation {
	
}

@property (strong) NSURL *rootURL;
@property (strong) DAVCredentials *credentials;
@property (assign) BOOL allowUntrustedCertificate;

@property DAVCompletionBlock strongboxCompletion;

@end
