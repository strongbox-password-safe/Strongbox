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

@property (nonatomic, readonly) BOOL isGroup;

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *password;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *url;
@property (nonatomic, strong, readonly) NSString *notes;

@property (readonly) NSString *groupPathPrefix;
@property (readonly) Group *group;
@property (readonly) Record *record;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initAsRootGroup;
- (instancetype)initWithGroup:(Group *)group NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithRecord:(Record *)record NS_DESIGNATED_INITIALIZER;

- (BOOL)isRootGroup;
- (SafeItemViewModel*)getParentGroup;

- (NSString*)description;

@end
