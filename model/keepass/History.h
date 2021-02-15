//
//  History.h
//  Strongbox
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"

@class Entry;

NS_ASSUME_NONNULL_BEGIN

@interface History : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property NSMutableArray<Entry*> *entries;

@end

NS_ASSUME_NONNULL_END
