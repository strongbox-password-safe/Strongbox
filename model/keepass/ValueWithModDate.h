//
//  ValueWithModDate.h
//  Strongbox
//
//  Created by Strongbox on 28/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ValueWithModDate : NSObject

+ (instancetype)value:(NSString*)value modified:(NSDate*_Nullable)modified;

@property (readonly) NSString* value;
@property (readonly, nullable) NSDate* modified;

@end

NS_ASSUME_NONNULL_END
