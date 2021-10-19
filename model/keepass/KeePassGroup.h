//
//  Group.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "Times.h"
#import "Entry.h"
#import "KeePassGroupOrEntry.h"
#import "CustomData.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassGroup : BaseXmlDomainObjectHandler <KeePassGroupOrEntry>

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initAsKeePassRoot:(XmlProcessingContext*)context;

@property (nonatomic) NSUUID* uuid;
@property (nonatomic) NSString* name;
@property (nonatomic, nullable) NSString* notes; 
@property (nonatomic, nullable) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;
@property (nonatomic) Times* times;
@property BOOL isExpanded;
@property (nonatomic, nullable) NSString* defaultAutoTypeSequence; 
@property (nonatomic, nullable) NSNumber* enableAutoType; 
@property (nonatomic, nullable) NSNumber* enableSearching; 
@property (nonatomic, nullable) NSUUID* lastTopVisibleEntry; 
@property (nonatomic, nullable) CustomData* customData;
@property (nonatomic) NSMutableArray<id<KeePassGroupOrEntry>>* groupsAndEntries;



@property NSMutableSet<NSString*> *tags;
@property (nullable) NSUUID* previousParentGroup;

@end

NS_ASSUME_NONNULL_END
