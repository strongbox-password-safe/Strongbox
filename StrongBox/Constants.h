//
//  Constants.h
//  Strongbox
//
//  Created by Strongbox on 22/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

#else

#import <AppKit/AppKit.h>

#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabasesCollectionLockStateChangedNotification;

extern NSString *const kPreferenceGlobalShowShortcutNotification;
extern NSString *const kPreferenceLaunchQuickSearchShortcut;
extern NSString *const kPreferencePasswordGeneratorShortcut;
extern NSString *const kSettingsChangedNotification;
extern NSString *const kTotpUpdateNotification;
extern NSString* const kProStatusChangedNotification;
extern NSString* const kAutoFillChangedConfigNotification;

extern NSString* const kKeePassXcTotpSeedKey;
extern NSString* const kKeePassXcTotpSettingsKey;
extern NSString* const kKeeOtpPluginKey;
extern NSString* const kOriginalWindowsSecretKey;
extern NSString* const kOriginalWindowsSecretHexKey;
extern NSString* const kOriginalWindowsSecretBase32Key;
extern NSString* const kOriginalWindowsSecretBase64Key;
extern NSString* const kOriginalWindowsOtpLengthKey;
extern NSString* const kOriginalWindowsOtpPeriodKey;
extern NSString* const kOriginalWindowsOtpAlgoKey;
extern NSString* const kOriginalWindowsOtpAlgoValueSha256;
extern NSString* const kOriginalWindowsOtpAlgoValueSha512;

extern NSString* const kPasskeyCustomFieldKeyRelyingParty;
extern NSString* const kPasskeyCustomFieldKeyUserId;
extern NSString* const kPasskeyCustomFieldKeyKpXcUpdatedCredentialId;
extern NSString* const kPasskeyCustomFieldKeyPrivateKeyPem;
extern NSString* const kPasskeyCustomFieldKeyUserHandle;

extern NSString* const kPasskeyCustomFieldKeyUsernameIncorrect;
extern NSString* const kPasskeyCustomFieldKeyUsernameCanonical;

extern NSString* const kDocumentRestorationNSCoderKeyForUrl;

@interface Constants : NSObject

@property (class, readonly) const NSSet<NSString*>* ReservedCustomFieldKeys;
@property (class, readonly) const NSSet<NSString*>* TotpCustomFieldKeys;
@property (class, readonly) const NSSet<NSString*>* PasskeyCustomFieldKeys;

extern NSString* const kTitleStringKey;
extern NSString* const kUserNameStringKey;
extern NSString* const kPasswordStringKey;
extern NSString* const kUrlStringKey;
extern NSString* const kNotesStringKey;

extern const NSInteger kStorageProviderSFTPorWebDAVSecretMissingErrorCode;
extern const NSInteger kStorageProviderUserInteractionRequiredErrorCode;
extern NSString* const kStorageProviderUserInteractionRequiredErrorMessage;
extern const NSError* kUserInteractionRequiredError;
extern const NSUInteger kMinimumDatabasePrefixLengthForValidation;
extern const NSUInteger kStreamingSerializationChunkSize;
extern const size_t kMaxAttachmentTableviewIconImageSize;

extern NSString* const kCanonicalEmailFieldName;
extern NSString* const kCanonicalFavouriteTag;

extern NSString* const kStrongboxPasteboardName;
extern NSString* const kDragAndDropInternalUti;
extern NSString* const kDragAndDropExternalUti;
extern NSString* const kDragAndDropSideBarHeaderMoveInternalUti;

extern NSString* const kKeeAgentSettingsAttachmentName;

extern NSString* const kIsExcludedFromAutoFillCustomDataKey;

#if TARGET_OS_IPHONE

@property (class, readonly) UIColor* recycleBinTintColor;

#else

@property (class, readonly) NSColor* recycleBinTintColor;

#endif

@end

NS_ASSUME_NONNULL_END
