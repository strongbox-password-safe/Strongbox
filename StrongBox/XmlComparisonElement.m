//
//  XmlComparisonElement.m
//  StrongboxTests
//
//  Created by Mark on 03/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "XmlComparisonElement.h"
#import "SBLog.h"
@implementation XmlComparisonElement

- (instancetype)initWithElementName:(NSString*)elementName attributes:(NSDictionary*)attributes {
    self = [super init];
    if (self) {
        self.elementName = elementName;
        self.attributes = attributes ? attributes.mutableCopy : @{}.mutableCopy;
        self.text = @"";
        self.children = [NSMutableArray array];
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    return [self isEqual:object probe:NO];
}

- (BOOL)isEqual:(id)object probe:(BOOL)probe {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[XmlComparisonElement class]]) {
        return NO;
    }

    XmlComparisonElement* other = (XmlComparisonElement*)object;
    if (![self.elementName isEqualToString:other.elementName]) {
        return NO;
    }
    
    if(![self.attributes isEqualToDictionary:other.attributes]) {
        if(!probe) {
            slog(@"Different Attributes on [%@]", other);
        }
        return NO;
    }
    
    NSString* removeWsSelf = trm(self.text);
    NSString* removeWsOther = trm(other.text);
    
    if (![removeWsSelf isEqualToString:removeWsOther]) {
        if(!probe) {
            slog(@"Different Text on [%@]", other);
        }
        return NO;
    }

    NSMutableArray<XmlComparisonElement*>* othersRemaining = other.children.mutableCopy;
    for (XmlComparisonElement* child in self.children) {
        BOOL foundMatchingChild = NO;

        for (XmlComparisonElement* otherChild in othersRemaining) {
            if ([child isEqual:otherChild probe:NO]) {
                foundMatchingChild = YES;
                [othersRemaining removeObject:otherChild]; 
                break;
            }
        }
        
        if (!foundMatchingChild) {
            if(!probe) {
                slog(@"Different at [%@]", child);
            }
            return NO;
        }
    }
    
    return YES;
}

NSString* trm(NSString* foo) {
    return [foo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@%@>%@</%@>", self.elementName, self.attributes.count ? self.attributes : @"", trm(self.text), self.elementName];
}

@end
