//
//  AutoType.m
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassXmlAutoType.h"
#import "KeePassConstants.h"
#import "SimpleXmlValueExtractor.h"

@implementation KeePassXmlAutoType

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kAutoTypeElementName context:context]) {
        self.enabled = NO;
        self.dataTransferObfuscation = 0;
        self.defaultSequence = @"";
        self.asssociations = NSMutableArray.array;
    }

    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kAssociationElementName]) {
        return [[KeePassXmlAutoTypeAssociation alloc] initWithContext:self.context];
    }

    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kEnabledElementName]) {
        self.enabled = [SimpleXmlValueExtractor getBool:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kDataTransferObfuscationElementName]) {
        NSNumber* num = [SimpleXmlValueExtractor getNumber:completedObject];
        self.dataTransferObfuscation = num == nil ? 0 : num.integerValue;
        return YES;
    }
    if([withXmlElementName isEqualToString:kDefaultSequenceElementName]) {
        self.defaultSequence = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kAssociationElementName]) {
        [self.asssociations addObject:completedObject];
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

    if (![serializer writeElement:kEnabledElementName boolean:self.enabled]) return NO;

    if (![serializer writeElement:kDataTransferObfuscationElementName integer:self.dataTransferObfuscation]) return NO;

    if ( self.defaultSequence.length ) {
        if (![serializer writeElement:kDefaultSequenceElementName text:self.defaultSequence]) return NO;
    }

    for (KeePassXmlAutoTypeAssociation* association in self.asssociations) {
        if ( ![association writeXml:serializer] ) {
            return NO;
        }
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
    
    if (![object isKindOfClass:[KeePassXmlAutoType class]]) {
        return NO;
    }
    
    KeePassXmlAutoType* other = (KeePassXmlAutoType*)object;

    if (self.enabled != other.enabled) return NO;
    
    if (self.dataTransferObfuscation != other.dataTransferObfuscation) return NO;
    
    if ((self.defaultSequence == nil && other.defaultSequence != nil) || (self.defaultSequence != nil && ![self.defaultSequence isEqual:other.defaultSequence] )) {
        return NO;
    }
    
    if (self.asssociations.count != other.asssociations.count) return NO;
    
    int i=0;
    for (KeePassXmlAutoTypeAssociation* association in self.asssociations) {
        KeePassXmlAutoTypeAssociation* otherAssociation = other.asssociations[i++];
        if ( ![association isEqual:otherAssociation] ) return NO;
    }
    
    return YES;
}

@end
