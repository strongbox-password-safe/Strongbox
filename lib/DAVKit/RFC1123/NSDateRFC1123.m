//
//  NSDateRFC1123.m
//  Filmfest
//
//  Created by Marcus Rohrmoser on 19.08.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSDateRFC1123.h"

@implementation NSDate (NSDateRFC1123)

+(NSDate*)dateFromRFC1123:(NSString*)value_
{
    if(value_ == nil)
        return nil;
    static NSDateFormatter *rfc1123 = nil;
    if(rfc1123 == nil)
    {
        rfc1123 = [[NSDateFormatter alloc] init];
        rfc1123.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        rfc1123.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        rfc1123.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
    }
    NSDate *ret = [rfc1123 dateFromString:value_];
    if(ret != nil)
        return ret;
	
    static NSDateFormatter *rfc850 = nil;
    if(rfc850 == nil)
    {
        rfc850 = [[NSDateFormatter alloc] init];
        rfc850.locale = rfc1123.locale;
        rfc850.timeZone = rfc1123.timeZone;
        rfc850.dateFormat = @"EEEE',' dd'-'MMM'-'yy HH':'mm':'ss z";
    }
    ret = [rfc850 dateFromString:value_];
    if(ret != nil)
        return ret;
	
    static NSDateFormatter *asctime = nil;
    if(asctime == nil)
    {
        asctime = [[NSDateFormatter alloc] init];
        asctime.locale = rfc1123.locale;
        asctime.timeZone = rfc1123.timeZone;
        asctime.dateFormat = @"EEE MMM d HH':'mm':'ss yyyy";
    }
    return [asctime dateFromString:value_];
}


-(NSString*)rfc1123String
{
    static NSDateFormatter *df = nil;
    if(df == nil)
    {
        df = [[NSDateFormatter alloc] init];
        df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    }
    return [df stringFromDate:self];
}


#if 0
// Fri, 14 Aug 2009 14:45:31 GMT
NSLogD(@"Last-Modified: %@", [vc.response.allHeaderFields objectForKey:@"Last-Modified"]);
//		df.calendar = @"gregorian";
NSLogD(@"Now: %@", [NSDate date]);
for(NSString* fmt in [NSArray arrayWithObjects:@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l", @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t", @"u", @"v", @"w", @"x", @"y", @"z", nil])
{
    rfc1123.dateFormat = [NSString stringWithFormat:@"%@%@%@", fmt, fmt, fmt];
    rfc1123.dateFormat = fmt;
    NSLogD(@"Now (%@): %@", rfc1123.dateFormat, [rfc1123 stringFromDate:[NSDate date]]);
    rfc1123.dateFormat = [rfc1123.dateFormat uppercaseString];
    NSLogD(@"Now (%@): %@", rfc1123.dateFormat, [rfc1123 stringFromDate:[NSDate date]]);
}
#endif

@end