//
//  SafeDetails.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"

@interface SafeMetaData : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier;

- (void)removeTouchIdPassword;
@property (nonatomic, strong) NSString* touchIdPassword;

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileIdentifier;
@property (nonatomic) StorageProvider storageProvider;
@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isEnrolledForTouchId;
@property (nonatomic) BOOL offlineCacheEnabled;
@property (nonatomic) BOOL offlineCacheAvailable;
@property (nonatomic) BOOL hasUnresolvedConflicts;

@end

