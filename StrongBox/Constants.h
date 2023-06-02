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

#endif

NS_ASSUME_NONNULL_BEGIN

@interface Constants : NSObject

+ (const NSSet<NSString*>*)reservedCustomFieldKeys;
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

#if TARGET_OS_IPHONE

@property (class, readonly) UIColor* recycleBinTintColor;

#endif

@end

NS_ASSUME_NONNULL_END
