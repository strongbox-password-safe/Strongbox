//
//  YubiManager.m
//  Strongbox-iOS
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "YubiManager.h"
#import "Alerts.h"
#import <YubiKit.h>
#import "Utils.h"
#import "Settings.h"

typedef NS_ENUM (NSInteger, YubiKeyManagerInProgressState) {
    kInProgressStateInitial,
    kInProgressStateNFCHailingFrequenciesOpenWaitingToOpenComms,
    kInProgressStateNfcCommsOpenAndWaitingOnHmacSha1Response,
};

@interface YubiManager ()

@property YubiKeyManagerInProgressState inProgressState;
@property YubiKeyHardwareConfiguration *configuration;
@property NSData* challenge;
@property YubiKeyCRResponseBlock completion;

@end

static NSString* const kIso7816SessionStateKvoKey = @"iso7816SessionState";
static NSString* const kAccessorySessionStateKvoKey = @"sessionState";

@implementation YubiManager

+ (instancetype)sharedInstance {
    static YubiManager *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[YubiManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self startObservingNfcSession];
    }
    
    return self;
}

- (void)startObservingNfcSession {
    if (@available(iOS 11.0, *)) {
        YKFNFCSession* nfcSession = YubiKitManager.shared.nfcSession;
        [nfcSession addObserver:self forKeyPath:kIso7816SessionStateKvoKey options:kNilOptions context:nil];
    }
}

- (BOOL)yubiKeySupportedOnDevice {
    return NO; // TODO: When We get approval - YubiKitDeviceCapabilities.supportsISO7816NFCTags;
}

- (void)getResponse:(YubiKeyHardwareConfiguration*)configuration
          challenge:(NSData*)challenge
         completion:(nonnull YubiKeyCRResponseBlock)completion {
    if (configuration.mode == kNoYubiKey) {
        NSError* error = [Utils createNSError:@"Mode == kNoYubiKey" errorCode:-1];
        completion(NO, nil, error);
        return;
    }
    
    if (configuration.mode == kNfc && !YubiKitDeviceCapabilities.supportsISO7816NFCTags) {
        NSLog(@"Device does not support NFC Scanning...");
        NSError* error = [Utils createNSError:@"Device does not support NFC Scanning..." errorCode:-1];
        completion(NO, nil, error);
        return;
    }

    if (self.inProgressState != kInProgressStateInitial) {
        NSLog(@"Yubikey session already in progress. Cannot start another!");
        NSError* error = [Utils createNSError:@"Yubikey session already in progress..." errorCode:-1];
        completion(NO, nil, error);
        return;
    }
 
    self.inProgressState = kInProgressStateNFCHailingFrequenciesOpenWaitingToOpenComms;
    self.configuration = configuration;
    self.challenge = challenge;
    self.completion = completion;
    
    if (configuration.mode == kNfc) {
        [self getNfcResponse:challenge];
    }
}

- (void)getNfcResponse:(NSData*)challenge {
    if (@available(iOS 13.0, *)) {
        Settings.sharedInstance.suppressPrivacyScreen = YES;
        [YubiKitManager.shared.nfcSession startIso7816Session];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kIso7816SessionStateKvoKey]) {
        if (@available(iOS 13.0, *)) {
            YKFNFCSession* nfcSession = YubiKitManager.shared.nfcSession;

            NSLog(@"NFC Session State Changed to [%lu] and we are in state [%ld]",
                  (unsigned long)nfcSession.iso7816SessionState,
                  (long)self.inProgressState);

            if (nfcSession.iso7816SessionState == YKFNFCISO7816SessionStateOpen) {
                [self onNfcSessionOpened];
            }
            else if (nfcSession.iso7816SessionState == YKFNFCISO7816SessionStateClosed) {
                [self onNfcSessionClosed];
            }
        }
    }
    else if ([keyPath isEqualToString:kAccessorySessionStateKvoKey]) {
//        NSLog(@"Accessory change: [%@]", change);
//
//        YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;
//
//        if(accSession.sessionState == YKFAccessorySessionStateOpen) {
//            [self onSessionOpened:^(NSData *response, NSError *error) {
//               //                // Close session?
//            }];
//        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)onNfcSessionOpened {
    NSLog(@"NFC Session Opened");

    if(self.inProgressState == kInProgressStateNFCHailingFrequenciesOpenWaitingToOpenComms) {
        self.inProgressState = kInProgressStateNfcCommsOpenAndWaitingOnHmacSha1Response;
        
        NSLog(@"NFC Open... Requesting...");
        [self onSessionOpened:^(NSData *response, NSError *error) {
            [self onNfcChallengeResponseDone:response error:error];
        }];
    }
}

- (void)onNfcSessionClosed {
    NSLog(@"NFC Session Closed");

    Settings.sharedInstance.suppressPrivacyScreen = NO;
    
    if (self.inProgressState != kInProgressStateNfcCommsOpenAndWaitingOnHmacSha1Response) {
        NSLog(@"Resetting YubiManager state due to close outside of normal scan/open state.");
        
        YubiKeyCRResponseBlock completionCopy = self.completion; // Reset state but call the completion afterwards so we don't block a follow on scan request
        self.configuration = nil;
        self.challenge = nil;
        self.completion = nil;
        self.inProgressState = kInProgressStateInitial;

        if(completionCopy) {
            completionCopy(YES, nil, nil); // User Cancelled
        }        
    }
    else {
    //    NSLog(@"NOP because in state: [%ld]", (long)self.inProgressState);
    }
}

- (void)onSessionOpened:(void (^)(NSData *response, NSError *error))completion {
    YKFKeyChallengeResponseService *service = [[YKFKeyChallengeResponseService alloc] init];

    [service sendChallenge:self.challenge
                      slot:self.configuration.slot == kSlot1 ? YKFSlotOne : YKFSlotTwo
                completion:^(NSData *response, NSError *error) {
        completion(response, error);
    }];
}

- (void)onNfcChallengeResponseDone:(NSData*)response error:(NSError*)error {
    if (@available(iOS 13.0, *)) {
        NSLog(@"onNfcChallengeResponseDone - %@ => %@", response, error);

        YKFNFCSession* nfcSession = YubiKitManager.shared.nfcSession;
        [nfcSession stopIso7816Session];

        YubiKeyCRResponseBlock completionCopy = self.completion; // Reset state but call the completion afterwards so we don't block a follow on scan request
        
        self.configuration = nil;
        self.challenge = nil;
        self.completion = nil;
        self.inProgressState = kInProgressStateInitial;

        if(completionCopy) {
            if(error) {
                completionCopy(NO, nil, error);
            }
            else {
                completionCopy(NO, response, error);
            }
        }
    }
}

//- (void)do5Ci {
//    if(YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
//        NSLog(@"Device does not support MFI Accessory...");
//        return;
//    }
//
//    YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;
//
//    [accSession addObserver:self forKeyPath:kAccessorySessionStateKvoKey options:kNilOptions context:nil];
//
//    [accSession startSession];
//}

@end
