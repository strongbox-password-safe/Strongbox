//
//  Meta.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "GenericTextStringElementHandler.h"
#import "V3BinariesList.h"
#import "CustomIconList.h"
#import "GenericTextIntegerElementHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface Meta : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;

@property (nonatomic) GenericTextStringElementHandler *generator;
@property (nonatomic, nullable) GenericTextStringElementHandler *headerHash;
@property (nonatomic) V3BinariesList *v3binaries;
@property (nonatomic) CustomIconList *customIconList;

@property (nonatomic) GenericTextIntegerElementHandler *historyMaxItems;
@property (nonatomic) GenericTextIntegerElementHandler *historyMaxSize;

- (void)setHash:(NSString*)hash;

@end

NS_ASSUME_NONNULL_END
