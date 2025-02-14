//
//  YubiManager.m
//  Strongbox-iOS
//
//  Created by Mark on 28/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "YubiManager.h"
#import "Alerts.h"
#import <YubiKit.h>
#import "Utils.h"


#import "AppPreferences.h"
#import "VirtualYubiKeys.h"
#import "NSDate+Extensions.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

typedef NS_ENUM (NSInteger, YubiKeyManagerInProgressState) {
    kInProgressStateInitial,
    kInProgressStateHailingFrequenciesOpenWaitingToOpenComms,
    kInProgressStateCommsOpenAndWaitingOnHmacSha1Response,
};

typedef NS_ENUM (NSInteger, MfiActionState) {
    kMfiActionStateInitial, 
    kMfiActionStateInsert,
    kMfiActionStateReading,
    kMfiActionStatePleaseTouch,
};

@interface YubiManager () <YKFManagerDelegate, MFIKeyActionSheetViewDelegate>

@property YubiKeyManagerInProgressState inProgressState;
@property YubiKeyHardwareConfiguration *configuration;
@property NSData* challenge;
@property YubiKeyCRResponseBlock completion;
@property MFIKeyActionSheetView* mfiActionSheetView;
@property BOOL mfiConnected;

@property NSDate* lastRequestAt;

@end

@implementation YubiManager

- (void)resetState {
    self.mfiConnected = NO;
    self.configuration = nil;
    self.challenge = nil;
    self.completion = nil;
    self.inProgressState = kInProgressStateInitial;
}

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
        YubiKitManager.shared.delegate = self;
    }
    
    return self;
}

- (BOOL)yubiKeySupportedOnDevice {
    return YES; 


}



- (void)getResponse:(YubiKeyHardwareConfiguration*)configuration
          challenge:(NSData*)challenge
         completion:(nonnull YubiKeyCRResponseBlock)completion {
    __weak YubiManager* weakSelf = self;
    
    YubiKeyCRResponseBlock wrapper = ^(BOOL userCancelled, NSData*_Nullable response, NSError*_Nullable error) {
        weakSelf.lastRequestAt = NSDate.date;
        completion(userCancelled, response, error);
    };


    
    const int delay = 3; 
    
    if ( self.lastRequestAt == nil || [self.lastRequestAt isMoreThanXSecondsAgo:delay] ) {
        [self getResponseThrottled:configuration challenge:challenge completion:wrapper];
    }
    else {
        slog(@"Throttling YubiKey request...");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
            [weakSelf getResponseThrottled:configuration challenge:challenge completion:wrapper];
        });
    }
}

- (void)getResponseThrottled:(YubiKeyHardwareConfiguration*)configuration
                   challenge:(NSData*)challenge
                  completion:(nonnull YubiKeyCRResponseBlock)completion {
    if (configuration.mode == kNoYubiKey) {
        NSError* error = [Utils createNSError:@"Mode == kNoYubiKey" errorCode:-1];
        completion(NO, nil, error);
        return;
    }
    
    if (configuration.mode == kVirtual) {
        VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:configuration.virtualKeyIdentifier];
        
        if (!key) {
            NSError* error = [Utils createNSError:@"Could not find Virtual Hardware Key!" errorCode:-1];
            completion(NO, nil, error);
        }
        else {
            slog(@"Doing Virtual Challenge Response...");
            NSData* response = [key doChallengeResponse:challenge];
            completion(NO, response, nil);
        }
        return;
    }
    
    if (configuration.mode == kNfc && !YubiKitDeviceCapabilities.supportsISO7816NFCTags) {
        slog(@"Device does not support NFC Scanning...");
        NSError* error = [Utils createNSError:@"Device does not support NFC Scanning..." errorCode:-1];
        completion(NO, nil, error);
        return;
    }








    if (self.inProgressState != kInProgressStateInitial) {
        slog(@"YubiKey session already in progress. Cannot start another!");
        NSError* error = [Utils createNSError:@"YubiKey session already in progress..." errorCode:-1];
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
    if(!YubiKitDeviceCapabilities.supportsISO7816NFCTags ) {
        slog(@"🔴 Device does not support ISO7816 NFC Tags...");
        return;
    }

    AppPreferences.sharedInstance.suppressAppBackgroundTriggers = YES;
    
    [YubiKitManager.shared startNFCConnection];
}

- (void)getMfiResponse:(NSData*)challenge {
    if(!YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
        slog(@"🔴 Device does not support MFI Accessory...");
        return;
    }

    [YubiKitManager.shared startAccessoryConnection];
    
    [self showMfiActionSheet:kMfiActionStateInitial];
}



- (void)onMfiConnected:(YKFAccessoryConnection*)connection {
    slog(@"MFI Session Opened");

    [self setMfiActionState:kMfiActionStateReading];

    if(self.inProgressState == kInProgressStateHailingFrequenciesOpenWaitingToOpenComms) {
        self.inProgressState = kInProgressStateCommsOpenAndWaitingOnHmacSha1Response;
        
        slog(@"MFI Open... Requesting...");

        [self onSessionOpened:connection completion:^(NSData *response, NSError *error) {
            [self onMfiChallengeResponseDone:response error:error];
        }];
    }
}

- (void)mfiKeyActionSheetDidDismiss {
    slog(@"mfiKeyActionSheetDidDismiss");
    
    [YubiKitManager.shared stopAccessoryConnection];
    
    self.mfiConnected = NO;
    
    [self onMfiDisconnected];
}

- (void)onMfiDisconnected {


    [self closeMfiActionSheet];
     
    YubiKeyCRResponseBlock completionCopy = self.completion; 
    self.configuration = nil;
    self.challenge = nil;
    self.completion = nil;
    self.inProgressState = kInProgressStateInitial;

    if(completionCopy) {
        completionCopy(YES, nil, nil); 
    }
}



- (void)onNfcConnected:(YKFNFCConnection*)connection {
    slog(@"🟢 NFC Session Opened");

    if(self.inProgressState == kInProgressStateHailingFrequenciesOpenWaitingToOpenComms) {
        self.inProgressState = kInProgressStateCommsOpenAndWaitingOnHmacSha1Response;
        
        slog(@"🟢 NFC Open... Requesting...");
        [self onSessionOpened:connection
                   completion:^(NSData *response, NSError *error) {
            [self onNfcChallengeResponseDone:response error:error];
        }];
    }
}

- (void)onNfcDisconnected {
    slog(@"NFC Session Closed");

    AppPreferences.sharedInstance.suppressAppBackgroundTriggers = NO;
    
    if (self.inProgressState != kInProgressStateCommsOpenAndWaitingOnHmacSha1Response) {
        slog(@"Resetting YubiManager state due to close outside of normal scan/open state.");
        
        YubiKeyCRResponseBlock completionCopy = self.completion; 
        self.configuration = nil;
        self.challenge = nil;
        self.completion = nil;
        self.inProgressState = kInProgressStateInitial;

        if(completionCopy) {
            completionCopy(YES, nil, nil); 
        }        
    }
}



- (void)onSessionOpened:(id<YKFConnectionProtocol>)connection completion:(void (^)(NSData *response, NSError *error))completion {
    slog(@"🟢 onSessionOpened - smartCardInterface = [%@]", connection.smartCardInterface);

    NSData* paddedChallenge = [self getPaddedChallenge];

    
    
    
    
    [self challengeResponse:connection challenge:paddedChallenge completion:completion];
}

- (void)challengeResponse:(id<YKFConnectionProtocol>)connection 
                challenge:(NSData*)challenge
               completion:(void (^)(NSData *response, NSError *error))completion {

    [connection challengeResponseSession:^(YKFChallengeResponseSession * _Nullable session, NSError * _Nullable error) {
        if ( !session || error ) {
            slog(@"🟢 onSessionOpened::sendChallenge coudl not get challengeResponseSession error = [%@]", error);
            completion(nil, error);
        }
        else {


            [session sendChallenge:challenge
                              slot:self.configuration.slot == kSlot1 ? YKFSlotOne : YKFSlotTwo
                        completion:^(NSData *response, NSError *error) {

                completion(response, error);
            }];
        }
    }];
}

- (void)onNfcChallengeResponseDone:(NSData*)response
                             error:(NSError*)error {


    [YubiKitManager.shared stopNFCConnection];

    YubiKeyCRResponseBlock completionCopy = self.completion; 
    
    [self resetState];
    
    if(completionCopy) {
        if(error) {
            completionCopy(NO, nil, error);
        }
        else {
            completionCopy(NO, response, error);
        }
    }
}

- (void)onMfiChallengeResponseDone:(NSData*)response error:(NSError*)error {
    slog(@"onMfiChallengeResponseDone - %@ => %@", response, error);

    [self closeMfiActionSheet];
    
    [YubiKitManager.shared stopAccessoryConnection];
        
    YubiKeyCRResponseBlock completionCopy = self.completion; 
    
    [self resetState];

    if(completionCopy) {
        if(error) {
            completionCopy(NO, nil, error);
        }
        else {
            completionCopy(NO, response, error);
        }
    }
}



- (void)didConnectAccessory:(YKFAccessoryConnection * _Nonnull)connection {
    YKFAccessoryDescription* ad = connection.accessoryDescription;
    slog(@"🟢 YubiManager::didConnectAccessory - [%@]-[%@]-[%@]-[%@]-[%@]-[%@]",  ad.manufacturer, ad.name, ad.modelNumber, ad.firmwareRevision, ad.hardwareRevision, ad.serialNumber);
    
    self.mfiConnected = YES;
    
    [self onMfiConnected:connection];
    
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ( self.mfiActionSheetView ) {
            [self setMfiActionState:kMfiActionStatePleaseTouch];
        }
    });
}

- (void)didDisconnectAccessory:(YKFAccessoryConnection * _Nonnull)connection error:(NSError * _Nullable)error {
    slog(@"🟢 YubiManager::didDisconnectAccessory");
    
    self.mfiConnected = NO;
    
    [self onMfiDisconnected];
}



- (void)didConnectNFC:(YKFNFCConnection * _Nonnull)connection {
    slog(@"🟢 YubiManager::didConnectNFC");
    
    [self onNfcConnected:connection];
}

- (void)didFailConnectingNFC:(NSError *)error {
    slog(@"🟢 YubiManager::didFailConnectingNFC - [%@]-[%ld]", error, (long)error.code);
    [self onNfcDisconnected];
}

- (void)didDisconnectNFC:(YKFNFCConnection * _Nonnull)connection error:(NSError * _Nullable)error { 
    slog(@"🟢 YubiManager::didDisconnectNFC - [%@]-[%ld]", error, (long)error.code); 
    
    [self onNfcDisconnected];
}





- (void)createMfiActionSheet {
    UIWindow* parentView = UIApplication.sharedApplication.keyWindow;

    self.mfiActionSheetView = [[MFIKeyActionSheetView alloc] initWithFrame:parentView.bounds];
    self.mfiActionSheetView.delegate = self;
    self.mfiActionSheetView.frame = parentView.bounds;
    
    [parentView addSubview:self.mfiActionSheetView];
}

- (void)showMfiActionSheet:(MfiActionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self internalSetMfiActionState:state];
        
        if (self.mfiActionSheetView == nil) {
            [self createMfiActionSheet];
        }
        
        [self.mfiActionSheetView presentWithAnimated:YES completion:^{
            [self internalSetMfiActionState:state];
        }];
    });
}

- (void)setMfiActionState:(MfiActionState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self internalSetMfiActionState:state];
    });
}

- (void)internalSetMfiActionState:(MfiActionState)state {
    if ( state == kMfiActionStateInitial ) {
        NSString* loc = NSLocalizedString(@"storage_provider_status_authenticating_connecting", @"Connecting...");
        [self.mfiActionSheetView animateTouchKeyWithMessage:loc];
        
        __weak YubiManager* weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ( weakSelf.mfiActionSheetView && !weakSelf.mfiConnected ) {
                [weakSelf setMfiActionState:kMfiActionStateInsert];
            }
        });
    }
    else if(state == kMfiActionStatePleaseTouch) {
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
    }
    
    
    
    [self.mfiActionSheetView updateInterfaceOrientationWithOrientation:UIApplication.sharedApplication.statusBarOrientation];
}

- (void)closeMfiActionSheet {


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



- (NSData*)getPaddedChallenge {
    
    
    
    
    
    
    const NSInteger kChallengeSize = 64;
    const NSInteger paddingLengthAndCharacter = kChallengeSize - self.challenge.length;
    uint8_t challengeBuffer[kChallengeSize];
    for(int i=0;i<kChallengeSize;i++) {
        challengeBuffer[i] = paddingLengthAndCharacter;
    }
    [self.challenge getBytes:challengeBuffer length:self.challenge.length];
    
    return [NSData dataWithBytes:challengeBuffer length:kChallengeSize];
}

@end

































































