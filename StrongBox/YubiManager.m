//
//  YubiManager.m
//  Strongbox-iOS
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "YubiManager.h"
#import <YubiKit.h>

@implementation YubiManager

+ (instancetype)sharedInstance {
    static YubiManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[YubiManager alloc] init];
    });
    return sharedInstance;
}

- (void)doIt {
    if (!YubiKitDeviceCapabilities.supportsNFCScanning) {
        NSLog(@"Device does not support NFC Scanning...");
        // TODO: Errors
        return;
    }
    
    NSLog(@"Requesting OTP Token...");
    
    [YubiKitManager.shared.nfcReaderSession requestOTPToken:^(id<YKFOTPTokenProtocol> _Nullable token, NSError * _Nullable error) {
        NSLog(@"Token: [%@] - Error: [%@]", token, error);
    }];
}

@end
