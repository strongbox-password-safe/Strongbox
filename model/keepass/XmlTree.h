//
//  XmlTree.h
//  Strongbox-iOS
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlTree : NSObject

@property (nonatomic) XmlItem* node;
@property (nonatomic) NSMutableArray<XmlTree*> *children;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithXmlElementName:(nonnull NSString*)xmlElementName NS_DESIGNATED_INITIALIZER;

- (BOOL)isXmlEquivalent_UnitTestOnly:(XmlTree*)other;

@end

NS_ASSUME_NONNULL_END
