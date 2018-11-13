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
#import "XmlProcessingContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseXmlDomainObjectHandler : NSObject<XmlParsingDomainObject>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context NS_DESIGNATED_INITIALIZER;

@property (nonatomic) XmlTree* nonCustomisedXmlTree;
@property (nonatomic) XmlProcessingContext* context;

@end

NS_ASSUME_NONNULL_END
