//
//  V3BinariesList.m
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "V3BinariesList.h"
#import "KeePassConstants.h"

@implementation V3BinariesList

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kV3BinariesListElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.binaries = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kBinaryElementName]) {
        return [[V3Binary alloc] initWithXmlElementName:kBinaryElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kBinaryElementName]) {
        [self.binaries addObject:(V3Binary*)completedObject];
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

    for (V3Binary *binary in self.binaries) {
        if ( ! [binary writeXml:serializer] ) {
            return NO;
        }
    }

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    return YES;
}

@end
