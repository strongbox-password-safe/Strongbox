//
//  NSDate+NSDate_Extensions_m.h
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (Extensions)

+ (BOOL)isMoreThanXMinutesAgo:(NSDate*_Nullable)date minutes:(NSUInteger)minutes;

- (BOOL)isMoreThanXSecondsAgo:(NSUInteger)seconds;

- (BOOL)isEqualToDateWithinEpsilon:(NSDate*)other;
- (BOOL)isLaterThan:(NSDate*)other;
- (BOOL)isEarlierThan:(NSDate*)other;

@property (readonly) NSString* friendlyDateString;
@property (readonly) NSString* friendlyDateStringVeryShort;
@property (readonly) NSString* friendlyDateTimeStringPrecise;
@property (readonly) NSString* iso8601DateString;
@property (readonly) NSString* friendlyTimeStringPrecise;
@property (readonly) NSString* friendlyDateTimeStringBothPrecise;

+ (instancetype)fromYYYY_MM_DDString:(NSString*)string;

@end

NS_ASSUME_NONNULL_END
