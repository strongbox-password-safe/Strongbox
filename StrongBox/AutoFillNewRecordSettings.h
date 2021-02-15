//
//  AutoFillNewRecordSettings.h
//  Strongbox-iOS
//
//  Created by Mark on 04/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (unsigned int, AutoFillMode) {
    kNone,
    kDefault,
    kMostUsed,
    kGenerated,
    kCustom,
};

@interface AutoFillNewRecordSettings : NSObject<NSCoding>

+ (AutoFillNewRecordSettings *)defaults;

@property (nonatomic) AutoFillMode titleAutoFillMode;
@property (nonatomic) NSString* titleCustomAutoFill;

@property (nonatomic) AutoFillMode usernameAutoFillMode;
@property (nonatomic) NSString* usernameCustomAutoFill;

@property (nonatomic) AutoFillMode passwordAutoFillMode;
@property (nonatomic) NSString* passwordCustomAutoFill;

@property (nonatomic) AutoFillMode emailAutoFillMode;
@property (nonatomic) NSString* emailCustomAutoFill;

@property (nonatomic) AutoFillMode urlAutoFillMode;
@property (nonatomic) NSString* urlCustomAutoFill;

@property (nonatomic) AutoFillMode notesAutoFillMode;
@property (nonatomic) NSString* notesCustomAutoFill;

@end

NS_ASSUME_NONNULL_END
