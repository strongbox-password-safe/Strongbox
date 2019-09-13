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

NS_ASSUME_NONNULL_BEGIN

@interface KeePassGroup : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initAsKeePassRoot:(XmlProcessingContext*)context;

@property (nonatomic) NSMutableArray<KeePassGroup*>* groups;
@property (nonatomic) NSMutableArray<Entry*>* entries;
@property (nonatomic) NSString* name;
@property (nonatomic) NSUUID* uuid;
@property (nonatomic, nullable) NSNumber* icon;
@property (nonatomic, nullable) NSUUID* customIcon;

@end

NS_ASSUME_NONNULL_END
