//
//  XmlToDictionaryParser.h
//  StrongboxTests
//
//  Created by Mark on 03/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlComparisonElement.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlToDictionaryParser : NSObject<NSXMLParserDelegate>

@property (nonatomic, readonly, nullable) XmlComparisonElement* rootElement;

@end

NS_ASSUME_NONNULL_END
