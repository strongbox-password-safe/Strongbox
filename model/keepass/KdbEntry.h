//
//  KdbEntry.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KdbEntry : NSObject

@property NSUUID *uuid;
@property uint32_t groupId;
@property NSNumber* imageId;
@property NSString *title;
@property NSString *url;
@property NSString *username;
@property NSString *password;
@property NSString *notes;
@property NSDate *creation;
@property NSDate *modified;
@property NSDate *accessed;
@property NSDate *expired;
@property NSString *binaryFileName;
@property NSData* binaryData;


@property (readonly) BOOL isMetaEntry;

@end

NS_ASSUME_NONNULL_END
