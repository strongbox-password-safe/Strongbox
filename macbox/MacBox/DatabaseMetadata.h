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

extern const NSInteger kDefaultPasswordExpiryHours;

@interface DatabaseMetadata : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                         fileUrl:(NSURL*)fileUrl
                     storageInfo:(NSString*)storageInfo;


@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSURL *fileUrl;
@property (nonatomic, strong) NSString *storageInfo;
@property (nonatomic) StorageProvider storageProvider;

@property (nonatomic, strong, readonly) NSString* touchIdPassword;
@property (nonatomic, strong) NSString* keyFileBookmark;
@property (nonatomic, strong) YubiKeyConfiguration* yubiKeyConfiguration;

@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isTouchIdEnrolled;
@property (nonatomic) BOOL hasPromptedForTouchIdEnrol;
@property (nonatomic) NSInteger touchIdPasswordExpiryPeriodHours;

- (SecretExpiryMode)getConveniencePasswordExpiryMode;
- (NSDate*)getConveniencePasswordExpiryDate;
    
- (NSString*)getConveniencePassword:(BOOL*)expired;
- (void)resetConveniencePasswordWithCurrentConfiguration:(NSString*)password;

@end
