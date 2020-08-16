//
//  NSDate+NSDate_Extensions_m.h
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (Extensions)

- (BOOL)isEqualToDateWithinEpsilon:(NSDate*)other;

@property (readonly) NSString* friendlyDateString;
@property (readonly) NSString* friendlyDateStringVeryShort;
@property (readonly) NSString* friendlyDateTimeStringPrecise;
@property (readonly) NSString* iso8601DateString;
@property (readonly) NSString* friendlyTimeStringPrecise;
@property (readonly) NSString* friendlyDateTimeStringBothPrecise;

@end

NS_ASSUME_NONNULL_END
