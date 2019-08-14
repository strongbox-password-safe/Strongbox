//
//  DAVRequest.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import "DAVRequest.h"

#import "DAVCredentials.h"
#import "DAVSession.h"

@interface DAVRequest ()

- (void)didFail:(NSError *)error;
- (void)didFinish;

@end


@implementation DAVRequest

NSString *const DAVClientErrorDomain = @"com.MattRajca.DAVKit.error";

#define DEFAULT_TIMEOUT 5 // seconds

@synthesize path = _path;
@synthesize delegate = _delegate;

- (id)initWithPath:(NSString *)aPath {
	self = [super init];
	if (self) {
		_path = [aPath == nil ? @"" : aPath copy];
        _timeout = DEFAULT_TIMEOUT;
    }
	return self;
}

- (NSURL *)concatenatedURLWithPath:(NSString *)aPath {
	NSParameterAssert(aPath != nil);

    NSURL* testHref = [NSURL URLWithString:aPath];
    if([testHref scheme] == nil) {
        testHref = [self.rootURL URLByAppendingPathComponent:aPath];
    }
    
    //NSLog(@"Determined URL: [%@]", testHref.absoluteString);
    return testHref;
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

- (BOOL)isCancelled {
	return _cancelled;
}

- (void)cancelWithCode:(NSInteger)code {
	[self willChangeValueForKey:@"isCancelled"];
	
	[_connection cancel];
	_cancelled = YES;
	
	[self didFail:[NSError errorWithDomain:DAVClientErrorDomain code:code userInfo:nil]];
	
	[self didChangeValueForKey:@"isCancelled"];
}

- (void)cancel {
	[self cancelWithCode:-1];
}

- (void)start {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(start) 
							   withObject:nil waitUntilDone:NO];
		
		return;
	}
	
	[self willChangeValueForKey:@"isExecuting"];
	
	_executing = YES;
	_connection = [NSURLConnection connectionWithRequest:[self request]
												delegate:self];
	
	if ([_delegate respondsToSelector:@selector(requestDidBegin:)])
		[_delegate requestDidBegin:self];
	
	[self didChangeValueForKey:@"isExecuting"];
}

- (NSURLRequest *)request {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:@"Subclasses of DAVRequest must override 'request'"
								 userInfo:nil];
	
	return nil;
}

- (id)resultForData:(NSData *)data {
	return nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (!_data) {
		_data = [[NSMutableData alloc] init];
	}
	
	[_data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self didFail:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSInteger code = [(NSHTTPURLResponse *)response statusCode];
		
		if (code >= 400) {
			[self cancelWithCode:code];
		}
	}
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
	BOOL result = [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault] ||
	[protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic] ||
	[protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest] ||
	[protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
	
	return result;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (self.allowUntrustedCertificate) {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
                 forAuthenticationChallenge:challenge];
        }
        
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    } else {
        if ([challenge previousFailureCount] == 0) {
            NSURLCredential *credential = [NSURLCredential credentialWithUser:self.credentials.username
                                                                     password:self.credentials.password
                                                                  persistence:NSURLCredentialPersistenceNone];
            
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        } else {
            // Wrong login/password
            [[challenge sender] cancelAuthenticationChallenge:challenge];
        }
    }
}

- (void)didFail:(NSError *)error {
	if ([_delegate respondsToSelector:@selector(request:didFailWithError:)]) {
		[_delegate request:self didFailWithError:error];
	}
	
	[self didFinish];
}

- (void)didFinish {
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"isFinished"];
	
	_done = YES;
	_executing = NO;
	
	[self didChangeValueForKey:@"isExecuting"];
	[self didChangeValueForKey:@"isFinished"];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if ([_delegate respondsToSelector:@selector(request:didSucceedWithResult:)]) {
		id result = [self resultForData:_data];
		
		[_delegate request:self didSucceedWithResult:result];
	}
	
	[self didFinish];
}

@end

@implementation DAVRequest (Private)

- (NSMutableURLRequest *)newRequestWithPath:(NSString *)path method:(NSString *)method {
	NSURL *url = [self concatenatedURLWithPath:path];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	[request setHTTPMethod:method];
	[request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setTimeoutInterval:self.timeout];
	
	return request;
}

@end
