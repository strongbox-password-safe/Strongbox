//
//  Constants.m
//  Strongbox
//
//  Created by Strongbox on 22/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Constants.h"
#import "Utils.h"

@implementation Constants

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

NSString* const kKeeAgentSettingsAttachmentName = @"KeeAgent.settings";

const static NSSet<NSString*> *wellKnownKeys;

+ (void)initialize {
    if(self == [Constants class]) {
        kUserInteractionRequiredError = [Utils createNSError:kStorageProviderUserInteractionRequiredErrorMessage errorCode:kStorageProviderUserInteractionRequiredErrorCode];

#if TARGET_OS_IPHONE
        kRecycleBinTintColor = ColorFromRGB(0x008f54); 
#endif
        
        wellKnownKeys = [NSSet setWithArray:@[  kTitleStringKey,
                                                kUserNameStringKey,
                                                kPasswordStringKey,
                                                kUrlStringKey,
                                                kNotesStringKey]];
    }
}

+ (const NSSet<NSString*>*)reservedCustomFieldKeys {
    return wellKnownKeys;
}

#if TARGET_OS_IPHONE

static UIColor* kRecycleBinTintColor;

+ (UIColor *)recycleBinTintColor {
    return kRecycleBinTintColor;
}

#endif

NSString* const kStrongboxPasteboardName = @"Strongbox-Pasteboard";
NSString* const kDragAndDropSideBarHeaderMoveInternalUti = @"com.markmcguill.strongbox.drag.and.drop.sidebar.header.move.internal.uti";
NSString* const kDragAndDropInternalUti = @"com.markmcguill.strongbox.drag.and.drop.internal.uti";
NSString* const kDragAndDropExternalUti = @"com.markmcguill.strongbox.drag.and.drop.external.uti";

@end
