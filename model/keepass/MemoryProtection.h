//
//  MemoryProtection.h
//  Strongbox
//
//  Created by Strongbox on 14/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface MemoryProtection : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;
- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context;













@property (nullable) NSNumber* protectTitle;
@property (nullable) NSNumber* protectUsername;
@property (nullable) NSNumber* protectPassword;
@property (nullable) NSNumber* protectURL;
@property (nullable) NSNumber* protectNotes;

@end

NS_ASSUME_NONNULL_END
