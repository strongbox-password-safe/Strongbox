//
//  AutoType.h
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseXmlDomainObjectHandler.h"
#import "KeePassXmlAutoTypeAssociation.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlAutoType : BaseXmlDomainObjectHandler

- (instancetype)initWithContext:(XmlProcessingContext*)context;

@property BOOL enabled;
@property NSInteger dataTransferObfuscation; 
@property (nullable) NSString* defaultSequence;
@property NSMutableArray<KeePassXmlAutoTypeAssociation*> *asssociations;







@end

NS_ASSUME_NONNULL_END
