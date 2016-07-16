//
//  Record.h
//  StrongBox
//
//  Created by Mark McGuill on 11/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeTools.h"
#import "Group.h"

@interface Record : NSObject

@property NSString *title;
@property NSString *password;
@property NSString *username;
@property NSString *url;
@property NSString *notes;
@property Group *group;
@property NSDate* accessed;
@property NSDate* modified;
@property NSDate* created;
@property NSDate* passwordModified;

@property (readonly) NSString* uuid;

-(void) generateNewUUID;
-(Record*)initWithFields:(NSDictionary*)fields;
-(NSArray*)getAllFields;

@end
