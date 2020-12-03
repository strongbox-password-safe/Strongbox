//
//  Group.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "Times.h"
#import "Entry.h"
#import "KeePassGroupOrEntry.h"
#import "MutableOrderedDictionary.h"
#import "CustomData.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassGroup : BaseXmlDomainObjectHandler <KeePassGroupOrEntry>

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initAsKeePassRoot:(XmlProcessingContext*)context;

@property (nonatomic) NSMutableArray<id<KeePassGroupOrEntry>>* groupsAndEntries;
@property (nonatomic) NSString* name;
@property (nonatomic) NSUUID* uuid;
@property (nonatomic, nullable) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;
@property (nonatomic) Times* times;
@property (nonatomic, nullable) CustomData* customData;
@property (nonatomic, nullable) NSString* notes; 
@property (nonatomic, nullable) NSString* defaultAutoTypeSequence; 
@property (nonatomic, nullable) NSNumber* enableAutoType; 
@property (nonatomic, nullable) NSNumber* enableSearching; 
@property (nonatomic, nullable) NSUUID* lastTopVisibleEntry; 



@end

NS_ASSUME_NONNULL_END
