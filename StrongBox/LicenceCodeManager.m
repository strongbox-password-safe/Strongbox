//
//  LicenceCodeManager.m
//  Strongbox-iOS
//
//  Created by Mark on 11/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LicenceCodeManager.h"

@implementation LicenceCodeManager

+ (instancetype)sharedInstance {
    static LicenceCodeManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LicenceCodeManager alloc] init];
    });
    return sharedInstance;
}

- (void)verifyCode:(NSString *)code completion:(VerifyCompletionBlock)completion {
    NSString *urlString2 = [NSString stringWithFormat:@"https://strongboxsafe.com/api/verifyLicence?code=%@", code];
    
    NSMutableURLRequest *request = [NSMutableURLRequest new];
    [request setURL:[NSURL URLWithString:urlString2]];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:nil
                                                     delegateQueue:[NSOperationQueue mainQueue]];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data,
                                                                NSURLResponse * _Nullable response,
                                                                NSError * _Nullable error) {
                                                NSHTTPURLResponse *asHTTPResponse = (NSHTTPURLResponse *) response;
                                                NSLog(@"The response is: %@ - %@", error, asHTTPResponse);
                                            
                                                completion(NO, error);
                                            }];
    [task resume];
}

@end
