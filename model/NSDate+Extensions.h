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

- (BOOL)isMoreThanXDaysAgo:(NSUInteger)days;
- (BOOL)isMoreThanXSecondsAgo:(NSUInteger)seconds;

- (BOOL)isEqualToDateWithinEpsilon:(NSDate*_Nullable)other;
- (BOOL)isLaterThan:(NSDate*)other;
- (BOOL)isEarlierThan:(NSDate*)other;

@property (readonly) BOOL isInPast;
@property (readonly) BOOL isInFuture;

@property (readonly) NSString* fileNameCompatibleDateTime;
@property (readonly) NSString* fileNameCompatibleDateTimePrecise;

@property (readonly) NSString* friendlyDateString;
@property (readonly) NSString* friendlyDateTimeString;
@property (readonly) NSString* friendlyDateStringVeryShort;
@property (readonly) NSString* friendlyDateStringVeryShortDateOnly;
@property (readonly) NSString* friendlyDateTimeStringPrecise;


@property (readonly) NSString* iso8601DateString; 
- (NSString*)iso8601DateStringWithFractionalSeconds;
+ (instancetype)FromIso8601DateStringWithFractionalSeconds:(NSString *)string;



@property (readonly) NSString* friendlyTimeStringPrecise;
@property (readonly) NSString* friendlyDateTimeStringBothPrecise;

+ (instancetype)fromYYYY_MM_DDString:(NSString*)string;
+ (instancetype)fromYYYY_MM_DD_London_Noon_Time_String:(NSString *)string;
+ (instancetype _Nullable )microsoftGraphDateFromString:(NSString *)dateString;

@end

NS_ASSUME_NONNULL_END
