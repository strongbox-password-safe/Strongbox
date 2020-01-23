//
//  SafeMetaData.h
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"

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
@property (nonatomic) BOOL isTouchIdEnabled;

@property (nonatomic, strong) NSString* touchIdPassword;
@property (nonatomic, strong) NSString* keyFileBookmark;

@property (nonatomic) BOOL hasPromptedForTouchIdEnrol;

@end
