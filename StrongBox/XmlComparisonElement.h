//
//  XmlComparisonElement.h
//  StrongboxTests
//
//  Created by Mark on 03/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XmlComparisonElement : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithElementName:(NSString*)elementName attributes:(NSDictionary*_Nullable)attributes NS_DESIGNATED_INITIALIZER;

@property NSString* elementName;
@property NSString* text;
@property NSMutableDictionary<NSString*, NSString*> *attributes;
@property NSMutableArray<XmlComparisonElement*> *children;

@end

NS_ASSUME_NONNULL_END
