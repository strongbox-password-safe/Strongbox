//
//  MemoryProtection.m
//  Strongbox
//
//  Created by Strongbox on 14/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MemoryProtection.h"
#import "SimpleXmlValueExtractor.h"
#import "KeePassConstants.h"

@implementation MemoryProtection

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kMemoryProtectionElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {

    }
    
    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kProtectTitleElementName]) {
        self.protectTitle = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kProtectUsernameElementName]) {
        self.protectUsername = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kProtectPasswordElementName]) {
        self.protectPassword = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kProtectURLElementName]) {
        self.protectURL = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    if([withXmlElementName isEqualToString:kProtectNotesElementName]) {
        self.protectNotes = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }

    return NO;
}

    
- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if ( self.protectTitle == nil && self.protectUsername == nil && self.protectPassword == nil && self.protectURL == nil && self.protectNotes == nil ) {
        return YES;
    }
    
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    if ( self.protectTitle != nil && ![serializer writeElement:kProtectTitleElementName boolean:self.protectTitle.boolValue] ) return NO;
    if ( self.protectUsername == nil && ![serializer writeElement:kProtectUsernameElementName boolean:self.protectUsername.boolValue] ) return NO;
    if ( self.protectPassword == nil && ![serializer writeElement:kProtectPasswordElementName boolean:self.protectPassword.boolValue] ) return NO;
    if ( self.protectURL == nil && ![serializer writeElement:kProtectURLElementName boolean:self.protectURL.boolValue] ) return NO;
    if ( self.protectNotes == nil && ![serializer writeElement:kProtectNotesElementName boolean:self.protectNotes.boolValue] ) return NO;

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

@end
