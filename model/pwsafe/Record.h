//
//  Record.h
//  StrongBox
//
//  Created by Mark McGuill on 11/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PwSafeSerialization.h"
#import "Group.h"
#import "PasswordHistory.h"

@interface Record : NSObject

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *email;
@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) NSString *notes;
@property (nonatomic, retain) NSDate *expires;

@property (nonatomic, retain) Group *group;
@property (nonatomic, retain) NSDate *accessed;
@property (nonatomic, retain) NSDate *modified;
@property (nonatomic, retain) NSDate *created;
@property (nonatomic, retain) NSDate *passwordModified;

@property (nonatomic, retain) NSUUID *uuid;
@property (nonatomic, retain) PasswordHistory *passwordHistory;

- (Record*)init;
- (Record *)initWithFields:(NSDictionary *)fields NS_DESIGNATED_INITIALIZER;
@property (NS_NONATOMIC_IOSONLY, getter = getAllFields, readonly, copy) NSArray *allFields;

@end
