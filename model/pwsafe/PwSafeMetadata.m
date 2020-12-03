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

- (instancetype)init {
    return [self initWithVersion:[NSString stringWithFormat:@"%ld.%ld", (long)kDefaultVersionMajor, (long)kDefaultVersionMinor]];
}

-(instancetype)initWithVersion:(NSString*)version {
    if(self = [super init]) {
        _version = version;
        self.keyStretchIterations = DEFAULT_KEYSTRETCH_ITERATIONS;
    }
    
    return self;
}

- (MutableOrderedDictionary<NSString*, NSString*>*)kvpForUi {
    MutableOrderedDictionary<NSString*, NSString*>* kvps = [[MutableOrderedDictionary alloc] init];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_format", @"Database Format")
        andValue:@"Password Safe 3"];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_password_safe_version", @"Password Safe File Version")  andValue:self.version];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_password_key_stretch_iterations", @"Key Stretch Iterations")
        andValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.keyStretchIterations]];
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_time", @"Last Update Time")
        andValue:[self formatDate:self.lastUpdateTime]];
    
    if (self.lastUpdateUser.length) {
        [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_user", @"Last Update User")
            andValue:self.lastUpdateUser];
    }
    
    [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_host", @"Last Update Host")
        andValue:self.lastUpdateHost];
    [kvps addKey:NSLocalizedString(@"database_metadata_field_last_update_app", @"Last Update App")
        andValue:self.lastUpdateApp];

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
