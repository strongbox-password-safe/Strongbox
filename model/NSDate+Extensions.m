//
//  NSDate_Extensions.m
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDate+Extensions.h"

@implementation NSDate (Extensions)

+ (BOOL)isMoreThanXMinutesAgo:(NSDate *)date minutes:(NSUInteger)minutes {
    if (date == nil) {
        return NO;
    }
    
    NSDate* ref = [NSDate.date dateByAddingTimeInterval:(minutes * -60.0f)];
    
    return [date isEarlierThan:ref];
}

- (BOOL)isEqualToDateWithinEpsilon:(NSDate *)other {
    if (other == nil) {
        return NO;
    }
    
    if ([self isEqualToDate:other]) {
        return YES;
    }
    
    NSTimeInterval interval = fabs([self timeIntervalSinceDate:other]);
    
    const NSTimeInterval epsilon = 0.00001;
    
    return interval < epsilon;
}

- (BOOL)isLaterThan:(NSDate*)other {
    if (other == nil) {
        return NO;
    }
    
    if ([self isEqualToDate:other]) {
        return NO;
    }

    return [self compare:other] == NSOrderedDescending;
}

- (BOOL)isEarlierThan:(NSDate*)other {
    if (other == nil) {
        return NO;
    }
    
    if ([self isEqualToDate:other]) {
        return NO;
    }

    return [self compare:other] == NSOrderedAscending;
}

- (NSString *)friendlyDateString {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterMediumStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;
    
    return [df stringFromDate:self];
}

- (NSString *)friendlyDateStringVeryShort {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;
    
    return [df stringFromDate:self];
}

- (NSString *)friendlyDateTimeStringPrecise {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    df.timeStyle = kCFDateFormatterMediumStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;

    return [df stringFromDate:self];
}

- (NSString *)friendlyTimeStringPrecise {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [df setLocale:enUSPOSIXLocale];
    [df setDateFormat:@"HH:mm:ss.SSS"];

    return [df stringFromDate:self];
}

- (NSString *)friendlyDateTimeStringBothPrecise {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [df setLocale:enUSPOSIXLocale];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];

    return [df stringFromDate:self];
}

- (NSString *)iso8601DateString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];

    return [dateFormatter stringFromDate:self];
}

@end
