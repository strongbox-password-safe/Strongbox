//
//  History.m
//  Strongbox
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "History.h"
#import "KeePassConstants.h"
#import "Entry.h"

@implementation History

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kHistoryElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.entries = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.entries addObject:(Entry*)completedObject];
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
    
    for (Entry *entry in self.entries) {
        [entry writeXml:serializer];
    }
    
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
    if (![object isKindOfClass:[History class]]) {
        return NO;
    }
    
    History* other = (History*)object;

    if(![self.entries isEqualToArray:other.entries]) {
        return NO;
    }
    
    return YES;
}

@end
