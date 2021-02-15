//
//  AutoTypeAssociationType.m
//  Strongbox
//
//  Created by Strongbox on 15/11/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassXmlAutoTypeAssociation.h"
#import "KeePassConstants.h"
#import "SimpleXmlValueExtractor.h"

@implementation KeePassXmlAutoTypeAssociation

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kAutoTypeAssociationElementName context:context]) {
        self.window = @"";
        self.keystrokeSequence = @"";
    }

    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kWindowElementName]) {
        self.window = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kKeystrokeSequenceElementName]) {
        self.keystrokeSequence = [SimpleXmlValueExtractor getStringFromText:completedObject];
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

    
    
    if (![serializer writeElement:kWindowElementName text:self.window ? self.window : @""]) return NO;
    if (![serializer writeElement:kKeystrokeSequenceElementName text:self.keystrokeSequence ? self.keystrokeSequence : @""]) return NO;

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
    
    if (![object isKindOfClass:[KeePassXmlAutoTypeAssociation class]]) {
        return NO;
    }
    
    KeePassXmlAutoTypeAssociation* other = (KeePassXmlAutoTypeAssociation*)object;

    if ((self.window == nil && other.window != nil) || (self.window != nil && ![self.window isEqual:other.window] )) {
        return NO;
    }

    if ((self.keystrokeSequence == nil && other.keystrokeSequence != nil) || (self.keystrokeSequence != nil && ![self.keystrokeSequence isEqual:other.keystrokeSequence] )) {
        return NO;
    }

    return YES;
}

@end
