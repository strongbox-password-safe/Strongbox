//
//  SafeItemViewModel.h
//  StrongBox
//
//  Created by Mark on 23/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Group.h"
#import "Record.h"

@interface SafeItemViewModel : NSObject

@property NSString*  title;
@property (readonly) BOOL       isGroup;
@property NSString*  password;
@property NSString*  username;
@property NSString*  url;
@property NSString*  notes;
@property (readonly) NSString*  groupPathPrefix;

@property (readonly) Group*     group;
@property (readonly) Record*    record;

-(id)initWithGroup:(Group*)group;
-(id)initWithRecord:(Record*)record;

@end
