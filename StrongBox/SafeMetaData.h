//
//  SafeDetails.h
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SafeMetaData : NSObject

typedef enum {
    kGoogleDrive,
    kDropbox,
    kLocalDevice,
} StorageProvider;

-(id)initWithNickName:(NSString*)nickName storageProvider:(StorageProvider)storageProvider;


@property NSString* nickName;
@property NSString* fileName;
@property NSString* fileIdentifier;
@property StorageProvider storageProvider;

@property BOOL isTouchIdEnabled;
@property BOOL isEnrolledForTouchId;

@property NSString* offlineCacheFileIdentifier;
@property BOOL offlineCacheEnabled;
@property BOOL offlineCacheAvailable;

-(NSDictionary*) toDictionary;
+(SafeMetaData*) fromDictionary:(NSDictionary*)dictionary;

@end
