//
//  SafeDetails.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"
#import "DuressAction.h"

@interface SafeMetaData : NSObject

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier;

@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *nickName;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileIdentifier;
@property (nonatomic) StorageProvider storageProvider;

@property (nonatomic) BOOL hasBeenPromptedForConvenience;
@property (nonatomic) BOOL isEnrolledForConvenience;
@property (nonatomic, strong) NSString* convenienceMasterPassword;
@property (nonatomic, strong) NSData* convenenienceKeyFileDigest;

@property (nonatomic) BOOL isTouchIdEnabled;

@property (nonatomic, strong) NSString* conveniencePin;
@property (nonatomic, strong) NSString* duressPin;
@property (nonatomic) DuressAction duressAction;
@property (nonatomic) int failedPinAttempts;

@property (nonatomic) BOOL offlineCacheEnabled;
@property (nonatomic) BOOL offlineCacheAvailable;

@property (nonatomic) BOOL autoFillCacheEnabled;
@property (nonatomic) BOOL autoFillCacheAvailable;

@property (nonatomic) BOOL readOnly;
@property (nonatomic) BOOL hasUnresolvedConflicts;

@end

