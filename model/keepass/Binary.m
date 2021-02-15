//
//  Binary.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Binary.h"
#import "KeePassConstants.h"
#import "SimpleXmlValueExtractor.h"

@implementation Binary

- (instancetype)initWithContext:(XmlProcessingContext*)context
{
    if(self = [super initWithXmlElementName:kBinaryElementName context:context]) {
        self.filename = @"";
        self.index = 0;
    }
    
    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeyElementName]) {
        self.filename = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kValueElementName]) {
        self.index = (uint32_t)[SimpleXmlValueExtractor integerFromAttributeNamed:kBinaryValueAttributeRef xmlObject:completedObject];
        return YES;
    }
    
    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    if(![serializer writeElement:kKeyElementName text:self.filename ? self.filename : @""]) return NO;
    if(![serializer writeElement:kValueElementName
                            text:@""
                      attributes:@{ kBinaryValueAttributeRef : @(self.index).stringValue}]) return NO;
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[Binary class]]) {
        return NO;
    }
    
    Binary* other = (Binary*)object;
    
    if ([self.filename compare:other.filename] != NSOrderedSame) {
        return NO;
    }
    if (self.index != other.index) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ [%@] = [%ld] }", self.filename, (long)self.index];
}

@end
