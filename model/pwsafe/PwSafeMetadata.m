//
//  PwSafeMetadata.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PwSafeMetadata.h"
#import "PwSafeSerialization.h"

@implementation PwSafeMetadata

- (instancetype)init
{
    return [self initWithVersion:[NSString stringWithFormat:@"%ld.%ld", (long)kDefaultVersionMajor, (long)kDefaultVersionMinor]];
}

-(instancetype)initWithVersion:(NSString*)version {
    if(self = [super init]) {
        _version = version;
        self.keyStretchIterations = DEFAULT_KEYSTRETCH_ITERATIONS;
    }
    
    return self;
}

- (BasicOrderedDictionary<NSString*, NSString*>*)kvpForUi {
    BasicOrderedDictionary<NSString*, NSString*>* kvps = [[BasicOrderedDictionary alloc] init];
    
    [kvps addKey:@"Database Format" andValue:@"Password Safe 3"];
    [kvps addKey:@"Password Safe File Version" andValue:self.version];
    [kvps addKey:@"Key Stretch Iterations" andValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.keyStretchIterations]];
    [kvps addKey:@"Last Update Time" andValue:[self formatDate:self.lastUpdateTime]];
    [kvps addKey:@"Last Update User" andValue:self.lastUpdateUser];
    [kvps addKey:@"Last Update Host" andValue:self.lastUpdateHost];
    [kvps addKey:@"Last Update App" andValue:self.lastUpdateApp];

    return kvps;
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) {
        return @"<Unknown>";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

@end
