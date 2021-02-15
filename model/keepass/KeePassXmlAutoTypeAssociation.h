//
//  AutoTypeAssociationType.h
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlAutoTypeAssociation : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property (nullable) NSString* window;
@property (nullable) NSString* keystrokeSequence;






@end

NS_ASSUME_NONNULL_END
