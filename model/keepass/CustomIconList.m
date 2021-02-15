//
//  CustomIconList.m
//  Strongbox
//
//  Created by Mark on 11/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CustomIconList.h"
#import "KeePassConstants.h"

@implementation CustomIconList

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kCustomIconListElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.icons = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kCustomIconElementName]) {
        return [[CustomIcon alloc] initWithXmlElementName:kCustomIconElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kCustomIconElementName]) {
        [self.icons addObject:(CustomIcon*)completedObject];
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
    
    for (CustomIcon *icon in self.icons) {
        [icon writeXml:serializer];
    }
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    return YES;
}

@end
