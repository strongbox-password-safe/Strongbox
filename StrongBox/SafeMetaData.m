//
//  SafeDetails.m
//  StrongBox
//
//  Created by Mark McGuill on 05/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeMetaData.h"

@implementation SafeMetaData

-(id)initWithNickName:(NSString*)nickName storageProvider:(StorageProvider)storageProvider
{
    self.nickName = nickName;
    self.storageProvider = storageProvider;
    
    self.isTouchIdEnabled = YES;
    self.offlineCacheEnabled = YES;
    
    return self;
}

-(NSDictionary*) toDictionary
{
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                self.nickName,                                              @"nickName",
                                self.fileIdentifier,                                        @"fileIdentifier",
                                self.fileName,                                              @"fileName",
                                [NSNumber numberWithInt:self.storageProvider],              @"storageProvider",
                                [NSNumber numberWithBool:self.isEnrolledForTouchId],        @"isEnrolledForTouchId",
                                [NSNumber numberWithBool:self.isTouchIdEnabled],            @"isTouchIdEnabled",
                                self.offlineCacheFileIdentifier,                            @"offlineCacheFileIdentifier",
                                [NSNumber numberWithBool:self.offlineCacheEnabled],         @"offlineCacheEnabled",
                                [NSNumber numberWithBool:self.offlineCacheAvailable],       @"offlineCacheAvailable",
                                nil];
    
    return dictionary;
}

+(SafeMetaData*) fromDictionary:(NSDictionary*)dictionary
{
    SafeMetaData* ret = [[SafeMetaData alloc] init];
    
    ret.nickName = [dictionary objectForKey:@"nickName"];
    ret.fileIdentifier = [dictionary objectForKey:@"fileIdentifier"];
    ret.fileName = [dictionary objectForKey:@"fileName"];
    
    NSNumber* sp = [dictionary valueForKey:@"storageProvider"];
    ret.storageProvider = sp ? [sp intValue] : kGoogleDrive;
    
    NSNumber* isEnrolledForTouchId = [dictionary valueForKey:@"isEnrolledForTouchId"];
    ret.isEnrolledForTouchId = isEnrolledForTouchId ? [isEnrolledForTouchId boolValue] : NO;
    
    NSNumber* isTouchIdEnabled = [dictionary valueForKey:@"isTouchIdEnabled"];
    ret.isTouchIdEnabled = isTouchIdEnabled ? [isTouchIdEnabled boolValue] : YES;
    
    ret.offlineCacheFileIdentifier = [dictionary objectForKey:@"offlineCacheFileIdentifier"];
    ret.offlineCacheFileIdentifier = (ret.offlineCacheFileIdentifier == nil) ? @"" : ret.offlineCacheFileIdentifier;
    
    NSNumber* offlineCacheEnabled = [dictionary valueForKey:@"offlineCacheEnabled"];
    ret.offlineCacheEnabled = offlineCacheEnabled ? [offlineCacheEnabled boolValue] : YES;
   
    NSNumber* offlineCacheAvailable = [dictionary valueForKey:@"offlineCacheAvailable"];
    ret.offlineCacheAvailable = offlineCacheAvailable ? [offlineCacheAvailable boolValue] : NO;
    
    return ret;
}

@end
