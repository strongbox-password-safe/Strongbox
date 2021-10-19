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

static NSString * const kProEditionBundleId = @"com.markmcguill.strongbox.pro";
static NSString * const kScotusEditionBundleId = @"com.markmcguill.strongbox.scotus";
static NSString * const kGrapheneEditionBundleId = @"com.markmcguill.strongbox.graphene";

NSString* const kDefaultKeePassEmailFieldKey = @"Email";

+(void)initialize {
    if(self == [Constants class]) {
        kUserInteractionRequiredError = [Utils createNSError:kStorageProviderUserInteractionRequiredErrorMessage errorCode:kStorageProviderUserInteractionRequiredErrorCode];
    }
}

+ (NSString *)proEditionBundleId {
    return kProEditionBundleId;
}

+ (NSString *)scotusEditionBundleId {
    return kScotusEditionBundleId;
}

+ (NSString *)grapheneEditionBundleId {
    return kGrapheneEditionBundleId;
}

@end
