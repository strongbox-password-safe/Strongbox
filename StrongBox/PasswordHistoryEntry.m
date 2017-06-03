//
//  PasswordHistoryEntry.m
//
//
//  Created by Mark on 28/05/2017.

#import "PasswordHistoryEntry.h"

@implementation PasswordHistoryEntry

- (instancetype)initWithPassword:(NSString *)password {
    return [self initWithTimestamp:[NSDate date] password:password];
}

- (instancetype)initWithTimestamp:(NSDate *)timestamp password:(NSString *)password {
    if (self = [super init]) {
        _timestamp = timestamp;
        _password = password;
        return self;
    }
    else {
        return nil;
    }
}

@end
