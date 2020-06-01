//
//  SafeMetaData.h
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"
#import "SecretStore.h"
#import "YubiKeyConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kDefaultPasswordExpiryHours;

@interface DatabaseMetadata : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo;


@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSURL *fileUrl; // This is really the primary key - at least at the moment
@property (nonatomic, strong, nullable) NSString *storageInfo; // This is extra info for accessing the file - usually a bookmark
@property (nonatomic) StorageProvider storageProvider;

@property (nonatomic, strong, readonly) NSString* conveniencePassword;
@property (nonatomic, strong, nullable) NSString* keyFileBookmark;
@property (nonatomic, strong) YubiKeyConfiguration* yubiKeyConfiguration;

@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isTouchIdEnrolled;
@property (nonatomic) BOOL hasPromptedForTouchIdEnrol;
@property (nonatomic) NSInteger touchIdPasswordExpiryPeriodHours;

- (SecretExpiryMode)getConveniencePasswordExpiryMode;
- (NSDate*)getConveniencePasswordExpiryDate;
    
- (NSString*)getConveniencePassword:(BOOL*_Nullable)expired;
- (void)resetConveniencePasswordWithCurrentConfiguration:(NSString*_Nullable)password; // null to clear

@end

NS_ASSUME_NONNULL_END
