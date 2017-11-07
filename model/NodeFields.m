//
//  NodeFields.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "NodeFields.h"

@implementation NodeFields

- (instancetype _Nullable)init {
    return [self initWithUsername:@""
                              url:@""
                         password:@""
                            notes:@""];
}

- (instancetype _Nullable)initWithUsername:(NSString*_Nonnull)username
                                       url:(NSString*_Nonnull)url
                                  password:(NSString*_Nonnull)password
                                     notes:(NSString*_Nonnull)notes {
    if (self = [super init]) {
        self.username = username;
        self.url = url;
        self.password = password;
        self.notes = notes;
        self.passwordHistory = [[PasswordHistory alloc] init];
        self.created = [NSDate date];
    }
    
    return self;
}

- (void)setPassword:(NSString *)password {
    if([password isEqualToString:_password]) {
        return;
    }
    
    _password = password;
    self.passwordModified = [NSDate date];
    
    PasswordHistory *pwHistory = self.passwordHistory;
    
    if (pwHistory.enabled && pwHistory.maximumSize > 0 && password) {
        [pwHistory.entries addObject:[[PasswordHistoryEntry alloc] initWithPassword:password]];
        
        if ((pwHistory.entries).count > pwHistory.maximumSize) {
            NSUInteger count = (pwHistory.entries).count;
            NSArray *slice = [pwHistory.entries subarrayWithRange:(NSRange) {count - pwHistory.maximumSize, pwHistory.maximumSize }];
            [pwHistory.entries removeAllObjects];
            [pwHistory.entries addObjectsFromArray:slice];
        }
    }
}

@end
