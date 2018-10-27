//
//  Group.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"
#import "GenericTextUuidElementHandler.h"
#import "Times.h"
#import "Entry.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassGroup : BaseXmlDomainObjectHandler

-(instancetype)initAsKeePassRoot;

@property (nonatomic) NSMutableArray<KeePassGroup*>* groups;
@property (nonatomic) NSMutableArray<Entry*>* entries;
@property (nonatomic) GenericTextStringElementHandler* name;
@property (nonatomic) GenericTextUuidElementHandler* uuid;

// TODO:
// <Notes />
// <IconID>48</IconID>

@end

NS_ASSUME_NONNULL_END
