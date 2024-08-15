//
//  YubiKeyConfiguration.h
//  MacBox
//
//  Created by Mark on 25/02/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// NB: Do not rename class is stored in NSCoding for config...

@interface YubiKeyConfiguration : NSObject

+ (instancetype)virtualKeyWithSerial:(NSString*)serial;
+ (instancetype)realKeyWithSerial:(NSString*)serial slot:(NSInteger)slot;

@property BOOL isVirtual;
@property NSString* deviceSerial; 
@property NSInteger slot; 

@end

NS_ASSUME_NONNULL_END
