//
//  SafeDetails.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SafeMetaData : NSObject

typedef NS_ENUM (unsigned int, StorageProvider) {
    kGoogleDrive,
    kDropbox,
    kLocalDevice,
    kiCloud,
};

- (instancetype)initWithNickName:(NSString *)nickName
                 storageProvider:(StorageProvider)storageProvider
                        fileName:(NSString*)fileName
                  fileIdentifier:(NSString*)fileIdentifier;

- (void)changeNickName:(NSString*)newNickName;

@property (nonatomic, strong, readonly) NSString *nickName;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileIdentifier;
@property (nonatomic) StorageProvider storageProvider;
@property (nonatomic) BOOL isTouchIdEnabled;
@property (nonatomic) BOOL isEnrolledForTouchId;
@property (nonatomic, strong) NSString *offlineCacheFileIdentifier;
@property (nonatomic) BOOL offlineCacheEnabled;
@property (nonatomic) BOOL offlineCacheAvailable;
@property (nonatomic) BOOL hasUnresolvedConflicts;

@property (nonatomic, readonly, copy) NSDictionary *toDictionary;
+ (SafeMetaData *)fromDictionary:(NSDictionary *)dictionary;

@end
