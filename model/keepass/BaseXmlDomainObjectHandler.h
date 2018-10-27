//
//  RootHandler.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlParsingDomainObject.h"
#import "XmlTree.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseXmlDomainObjectHandler : NSObject<XmlParsingDomainObject>

- (instancetype)init;
- (instancetype)initWithXmlElementName:(NSString*)xmlElementName NS_DESIGNATED_INITIALIZER;

@property (nonatomic) XmlTree* nonCustomisedXmlTree;

@end

NS_ASSUME_NONNULL_END
