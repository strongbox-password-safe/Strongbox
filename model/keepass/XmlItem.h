//
//  XmlItem.h
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XmlItem : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithXmlElementName:(nonnull NSString*)xmlElementName NS_DESIGNATED_INITIALIZER;

@property (nonatomic) NSString* xmlElementName;
@property (nonatomic) NSMutableDictionary* xmlAttributes;
@property (nonatomic) NSString *xmlText;

- (BOOL)isXmlEquivalent:(XmlItem*)other;

@end

NS_ASSUME_NONNULL_END
