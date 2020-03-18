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
#import "Strongbox-Swift.h"

typedef NS_ENUM (NSInteger, YubiKeyManagerInProgressState) {
    kInProgressStateInitial,
    kInProgressStateHailingFrequenciesOpenWaitingToOpenComms,
    kInProgressStateCommsOpenAndWaitingOnHmacSha1Response,
};

typedef NS_ENUM (NSInteger, MfiActionState) {
    kMfiActionStateInsert,
    kMfiActionStateReading,
    kMfiActionStatePleaseTouch,
};

@interface YubiManager () <MFIKeyActionSheetViewDelegate>

@property YubiKeyManagerInProgressState inProgressState;
@property YubiKeyHardwareConfiguration *configuration;
@property NSData* challenge;
@property YubiKeyCRResponseBlock completion;
@property MFIKeyActionSheetView* mfiActionSheetView;

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
        [self startObservingMfiSession];
    }
    
    return self;
}

- (BOOL)yubiKeySupportedOnDevice {
    return  YubiKitDeviceCapabilities.supportsISO7816NFCTags ||
            YubiKitDeviceCapabilities.supportsMFIAccessoryKey;
}

- (void)startObservingNfcSession {
    if (@available(iOS 11.0, *)) {
        if (YubiKitDeviceCapabilities.supportsISO7816NFCTags) {
            YKFNFCSession* nfcSession = YubiKitManager.shared.nfcSession;
            [nfcSession addObserver:self forKeyPath:kIso7816SessionStateKvoKey options:kNilOptions context:nil];
        }
    }
}

- (void)startObservingMfiSession {
    NSLog(@"startObservingMfiSession");
    
    if (YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
        YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;
        [accSession addObserver:self forKeyPath:kAccessorySessionStateKvoKey options:kNilOptions context:nil];
    }
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

    if (configuration.mode == kMfi && !YubiKitDeviceCapabilities.supportsMFIAccessoryKey ) {
        NSLog(@"Device does not support MFI Device...");
        NSError* error = [Utils createNSError:@"Device does not support MFI Device..." errorCode:-1];
        completion(NO, nil, error);
        return;
    }

    if (self.inProgressState != kInProgressStateInitial) {
        NSLog(@"Yubikey session already in progress. Cannot start another!");
        NSError* error = [Utils createNSError:@"Yubikey session already in progress..." errorCode:-1];
        completion(NO, nil, error);
        return;
    }
 
    self.inProgressState = kInProgressStateHailingFrequenciesOpenWaitingToOpenComms;
    self.configuration = configuration;
    self.challenge = challenge;
    self.completion = completion;
    
    if (configuration.mode == kNfc) {
        [self getNfcResponse:challenge];
    }
    else if (configuration.mode == kMfi) {
        [self getMfiResponse:challenge];
    }
}

- (void)getNfcResponse:(NSData*)challenge {
    if (@available(iOS 13.0, *)) {
        Settings.sharedInstance.suppressPrivacyScreen = YES;
        [YubiKitManager.shared.nfcSession startIso7816Session];
    }
}

- (void)getMfiResponse:(NSData*)challenge {
    if(!YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
        NSLog(@"Device does not support MFI Accessory...");
        return;
    }

    YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;

    NSLog(@"Starting MFI Session - State is currently [%lu] and we are in FSM state [%ld]. Key Connected = [%d]",
          (unsigned long)accSession.sessionState,
          (long)self.inProgressState,
          accSession.isKeyConnected);

    [self showMfiActionSheet:accSession.isKeyConnected ? kMfiActionStateReading : kMfiActionStateInsert];
    
    if (accSession.sessionState == YKFAccessorySessionStateOpen) {
        NSLog(@"Session already open - Requesting CR...");
        [self onMfiSessionOpened];
    }
    else {
        NSLog(@"Key is not connected and session not open startSession");
        [accSession startSession];
    }
}

- (void)createMfiActionSheet {
    UIWindow* parentView = UIApplication.sharedApplication.keyWindow;

    self.mfiActionSheetView = [MFIKeyActionSheetView loadViewFromNib];
    self.mfiActionSheetView.delegate = self;
    self.mfiActionSheetView.frame = parentView.bounds;
    [parentView addSubview:self.mfiActionSheetView];
}

- (void)showMfiActionSheet:(MfiActionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.mfiActionSheetView == nil) {
            [self createMfiActionSheet];
        }
        
        [self.mfiActionSheetView presentWithAnimated:YES completion:^{}];
        [self internalSetMfiActionState:state];
    });
}

- (void)setMfiActionState:(MfiActionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self internalSetMfiActionState:state];
    });
}

- (void)internalSetMfiActionState:(MfiActionState)state {
    YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;

    NSLog(@"internalSetMfiActionState: %ld, %lu", (long)state, (unsigned long)accSession.sessionState);
    
    if(state == kMfiActionStatePleaseTouch) {
        NSString* loc = NSLocalizedString(@"yubikey_touch_the_key_to_read_the_otp", @"Touch the key to read the OTP");
        [self.mfiActionSheetView animateTouchKeyWithMessage:loc];
    }
    else if(state == kMfiActionStateInsert) {
        NSString* loc = NSLocalizedString(@"yubikey_insert_the_key_to_read_the_otp", @"Insert the key to read the OTP");
        [self.mfiActionSheetView animateInsertKeyWithMessage:loc];
    }
    else {
        NSString* loc = NSLocalizedString(@"yubikey_communicating_with_key_ellipsis", @"Communicating with YubiKey...");
        [self.mfiActionSheetView animateProcessingWithMessage:loc];
        
        // If we're still around in 0.75 seconds ask user to touch
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if(self.mfiActionSheetView) {
                [self setMfiActionState:kMfiActionStatePleaseTouch];
            }
        });
    }
    
    // We probably need to update this whenever we can? viewWillTransition ?
    [self.mfiActionSheetView updateInterfaceOrientationWithOrientation:UIApplication.sharedApplication.statusBarOrientation];
}

- (void)closeMfiActionSheet {
    NSLog(@"closeMfiActionSheet [%@]", self.mfiActionSheetView);
    
    MFIKeyActionSheetView* view = self.mfiActionSheetView;
    self.mfiActionSheetView = nil;
    
    if(view) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [view dismissWithAnimated:YES delayed:NO completion:^{
                [view removeFromSuperview];
            }];
        });
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
        YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;

        NSLog(@"MFI Session State Changed to [%lu] and we are in state [%ld]",
               (unsigned long)accSession.sessionState,
              (long)self.inProgressState);

        if(accSession.sessionState == YKFAccessorySessionStateOpen && self.inProgressState != kInProgressStateInitial) {
            [self onMfiSessionOpened];
        }
        else if (accSession.sessionState == YKFAccessorySessionStateClosed) {
            [self onMfiSessionClosed];
        }
        else {
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)mfiKeyActionSheetDidDismiss:(MFIKeyActionSheetView * _Nonnull)actionSheet {
    NSLog(@"mfiKeyActionSheetDidDismiss");
    
    YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;
    
    if (accSession.sessionState == YKFAccessorySessionStateOpen ||
        accSession.sessionState == YKFAccessorySessionStateOpening) {

        [accSession cancelCommands];
        [accSession stopSession];
    }
    
    [self onMfiSessionClosed];
}

- (void)onMfiSessionOpened {
    NSLog(@"MFI Session Opened");

    [self setMfiActionState:kMfiActionStateReading];

    if(self.inProgressState == kInProgressStateHailingFrequenciesOpenWaitingToOpenComms) {
        self.inProgressState = kInProgressStateCommsOpenAndWaitingOnHmacSha1Response;
        
        NSLog(@"MFI Open... Requesting...");
        [self onSessionOpened:^(NSData *response, NSError *error) {
            [self onMfiChallengeResponseDone:response error:error];
        }];
    }
}

- (void)onMfiSessionClosed {
    NSLog(@"MFI Session Closed and we are in state = %ld", (long)self.inProgressState);

    [self closeMfiActionSheet];
     
    YubiKeyCRResponseBlock completionCopy = self.completion; // Reset state but call the completion afterwards so we don't block a follow on scan request
    self.configuration = nil;
    self.challenge = nil;
    self.completion = nil;
    self.inProgressState = kInProgressStateInitial;

    if(completionCopy) {
        completionCopy(YES, nil, nil); // User Cancelled
    }
}

- (void)onNfcSessionOpened {
    NSLog(@"NFC Session Opened");

    if(self.inProgressState == kInProgressStateHailingFrequenciesOpenWaitingToOpenComms) {
        self.inProgressState = kInProgressStateCommsOpenAndWaitingOnHmacSha1Response;
        
        NSLog(@"NFC Open... Requesting...");
        [self onSessionOpened:^(NSData *response, NSError *error) {
            [self onNfcChallengeResponseDone:response error:error];
        }];
    }
}

- (void)onNfcSessionClosed {
    NSLog(@"NFC Session Closed");

    Settings.sharedInstance.suppressPrivacyScreen = NO;
    
    if (self.inProgressState != kInProgressStateCommsOpenAndWaitingOnHmacSha1Response) {
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
}

- (void)onSessionOpened:(void (^)(NSData *response, NSError *error))completion {
    YKFKeyChallengeResponseService *service = [[YKFKeyChallengeResponseService alloc] init];

    // Some people program the Yubikey with Fixed Length "Fixed 64 byte input" and others with "Variable Input"
    // To cover both cases the KeePassXC model appears to be to always send 64 bytes with extraneous bytes above
    // and beyond the actual challenge padded PKCS#7 style-ish... MMcG - 1-Mar-2020
    //
    // Further Reading: https://github.com/Yubico/yubikey-personalization-gui/issues/86

    const NSInteger kChallengeSize = 64;
    const NSInteger paddingLengthAndCharacter = kChallengeSize - self.challenge.length;
    uint8_t challengeBuffer[kChallengeSize];
    for(int i=0;i<kChallengeSize;i++) {
        challengeBuffer[i] = paddingLengthAndCharacter;
    }
    [self.challenge getBytes:challengeBuffer length:self.challenge.length];
    
    NSData* paddedChallenge = [NSData dataWithBytes:challengeBuffer length:kChallengeSize];
    [service sendChallenge:paddedChallenge
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

- (void)onMfiChallengeResponseDone:(NSData*)response error:(NSError*)error {
    NSLog(@"onMfiChallengeResponseDone - %@ => %@", response, error);

    [self closeMfiActionSheet];

    YKFAccessorySession *accSession = YubiKitManager.shared.accessorySession;
    [accSession stopSession];
    
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

@end
