//
//  DAVCredentials.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVCredentials.h"

@implementation DAVCredentials

@synthesize username = _username;
@synthesize password = _password;

+ (id)credentialsWithUsername:(NSString *)username password:(NSString *)password {
	return [[[self class] alloc] initWithUsername:username password:password];
}

- (id)initWithUsername:(NSString *)username password:(NSString *)password {
	NSParameterAssert(username != nil);
	NSParameterAssert(password != nil);
	
	self = [super init];
	if (self) {
		_username = [username copy];
		_password = [password copy];
	}
	return self;
}

@end
