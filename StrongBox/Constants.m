//
//  Constants.m
//  Strongbox
//
//  Created by Strongbox on 22/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Constants.h"
#import "Utils.h"
#import "NSArray+Extensions.h"

@implementation Constants

NSString* const kDatabasesCollectionLockStateChangedNotification = @"DatabasesCollectionLockStateChangedNotification";

NSString *const kPreferenceGlobalShowShortcutNotification = @"GlobalShowStrongboxHotKey-New";
NSString *const kPreferenceLaunchQuickSearchShortcut = @"LaunchQuickSearchShortcut";
NSString *const kPreferencePasswordGeneratorShortcut = @"PasswordGeneratorShortcut";

NSString *const kSettingsChangedNotification = @"settingsChangedNotification";
NSString *const kTotpUpdateNotification = @"TotpUpdateNotification";
NSString* const kProStatusChangedNotification = @"proStatusChangedNotification";
NSString* const kAutoFillChangedConfigNotification = @"autoFillChangedConfigNotification";

const NSInteger kStorageProviderSFTPorWebDAVSecretMissingErrorCode = 172924134;

const NSInteger kStorageProviderUserInteractionRequiredErrorCode = 17292412;
NSString* const kStorageProviderUserInteractionRequiredErrorMessage = @"User Interaction Required";
const NSError* kUserInteractionRequiredError;
const NSUInteger kMinimumDatabasePrefixLengthForValidation = 192;
const NSUInteger kStreamingSerializationChunkSize = 128 * 1024; 
const size_t kMaxAttachmentTableviewIconImageSize = 4 * 1024 * 1024;


NSString* const kCanonicalEmailFieldName = @"Email";
NSString* const kCanonicalFavouriteTag = @"Favorite";

NSString* const kTitleStringKey = @"Title";
NSString* const kUserNameStringKey = @"UserName";
NSString* const kPasswordStringKey = @"Password";
NSString* const kUrlStringKey = @"URL";
NSString* const kNotesStringKey = @"Notes";

NSString* const kKeePassXcTotpSeedKey = @"TOTP Seed";
NSString* const kKeePassXcTotpSettingsKey = @"TOTP Settings";
NSString* const kKeeOtpPluginKey = @"otp";
NSString* const kOriginalWindowsSecretKey = @"TimeOtp-Secret";
NSString* const kOriginalWindowsSecretHexKey = @"TimeOtp-Secret-Hex";
NSString* const kOriginalWindowsSecretBase32Key = @"TimeOtp-Secret-Base32";
NSString* const kOriginalWindowsSecretBase64Key = @"TimeOtp-Secret-Base64";
NSString* const kOriginalWindowsOtpLengthKey = @"TimeOtp-Length";
NSString* const kOriginalWindowsOtpPeriodKey = @"TimeOtp-Period";
NSString* const kOriginalWindowsOtpAlgoKey = @"TimeOtp-Algorithm";
NSString* const kOriginalWindowsOtpAlgoValueSha256 = @"HMAC-SHA-256";
NSString* const kOriginalWindowsOtpAlgoValueSha512 = @"HMAC-SHA-512";

NSString* const kKeeAgentSettingsAttachmentName = @"KeeAgent.settings";

NSString* const kIsExcludedFromAutoFillCustomDataKey = @"KPEX_DoNotSuggestForAutoFill";

NSString* const kPasskeyCustomFieldKeyRelyingParty = @"KPEX_PASSKEY_RELYING_PARTY";
NSString* const kPasskeyCustomFieldKeyUserId = @"KPEX_PASSKEY_GENERATED_USER_ID";
NSString* const kPasskeyCustomFieldKeyKpXcUpdatedCredentialId = @"KPEX_PASSKEY_CREDENTIAL_ID";
NSString* const kPasskeyCustomFieldKeyPrivateKeyPem = @"KPEX_PASSKEY_PRIVATE_KEY_PEM";
NSString* const kPasskeyCustomFieldKeyUserHandle = @"KPEX_PASSKEY_USER_HANDLE";

NSString* const kPasskeyCustomFieldKeyUsernameIncorrect = @"KPXC_PASSKEY_USERNAME";
NSString* const kPasskeyCustomFieldKeyUsernameCanonical = @"KPEX_PASSKEY_USERNAME";

NSString* const kDocumentRestorationNSCoderKeyForUrl = @"StrongboxNonFileRestorationStateURLAsString";

const static NSSet<NSString*> *wellKnownKeys;

+ (void)initialize {
    if(self == [Constants class]) {
        kUserInteractionRequiredError = [Utils createNSError:kStorageProviderUserInteractionRequiredErrorMessage errorCode:kStorageProviderUserInteractionRequiredErrorCode];

#if TARGET_OS_IPHONE
        kRecycleBinTintColor = ColorFromRGB(0x7DC583); 
#else
        kRecycleBinTintColor = ColorFromRGB(0x7DC583); 
#endif
        
        wellKnownKeys = [NSSet setWithArray:@[  kTitleStringKey,
                                                kUserNameStringKey,
                                                kPasswordStringKey,
                                                kUrlStringKey,
                                                kNotesStringKey]];
    }
}

+ (const NSSet<NSString *> *)TotpCustomFieldKeys {
    static NSSet<NSString*>* totpKeys;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        totpKeys = @[kKeeOtpPluginKey,
                     kKeePassXcTotpSeedKey,
                     kKeePassXcTotpSettingsKey,
                     kOriginalWindowsSecretKey,
                     kOriginalWindowsSecretHexKey,
                     kOriginalWindowsSecretBase32Key,
                     kOriginalWindowsSecretBase64Key,
                     kOriginalWindowsOtpLengthKey,
                     kOriginalWindowsOtpPeriodKey,
                     kOriginalWindowsOtpAlgoKey].set;
    });
    
    return totpKeys;
}

+ (const NSSet<NSString *> *)ReservedCustomFieldKeys {
    return wellKnownKeys;
}

+ (const NSSet<NSString *> *)PasskeyCustomFieldKeys {
    static NSSet<NSString*>* keys;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        keys = @[
            kPasskeyCustomFieldKeyRelyingParty,
            kPasskeyCustomFieldKeyUserId,
            kPasskeyCustomFieldKeyKpXcUpdatedCredentialId,  
            kPasskeyCustomFieldKeyPrivateKeyPem,
            kPasskeyCustomFieldKeyUserHandle,
            kPasskeyCustomFieldKeyUsernameIncorrect,
            kPasskeyCustomFieldKeyUsernameCanonical, 
        ].set;
    });
    
    return keys;
}

#if TARGET_OS_IPHONE

static UIColor* kRecycleBinTintColor;

+ (UIColor *)recycleBinTintColor {
    return kRecycleBinTintColor;
}

#else

static NSColor* kRecycleBinTintColor;

+ (NSColor *)recycleBinTintColor {
    return kRecycleBinTintColor;
}

#endif

NSString* const kStrongboxPasteboardName = @"Strongbox-Pasteboard";
NSString* const kDragAndDropSideBarHeaderMoveInternalUti = @"com.markmcguill.strongbox.drag.and.drop.sidebar.header.move.internal.uti";
NSString* const kDragAndDropInternalUti = @"com.markmcguill.strongbox.drag.and.drop.internal.uti";
NSString* const kDragAndDropExternalUti = @"com.markmcguill.strongbox.drag.and.drop.external.uti";

@end
