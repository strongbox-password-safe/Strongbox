//
//  CustomIcon.m
//  Strongbox
//
//  Created by Mark on 11/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CustomIcon.h"
#import "KeePassConstants.h"
#import "SimpleXmlValueExtractor.h"

@implementation CustomIcon

- (void)dealloc {
//    slog(@"DEALLOC - CustomIcon");
}

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kCustomIconElementName context:context]) {
        self.uuid = [NSUUID UUID];
    }
    
    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconDataElementName]) {
        NSString* b64 = [SimpleXmlValueExtractor getStringFromText:completedObject];
        self.data = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters ];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kNameElementName]) {
        self.name = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kLastModificationTimeElementName]) {
        self.modified = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }

    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(!self.uuid) {
        return YES;
    }

    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    [serializer writeElement:kUuidElementName uuid:self.uuid];
    
    @autoreleasepool {
        self.data = self.data ? self.data : [NSData data];
        NSString *b64 = [self.data base64EncodedStringWithOptions:kNilOptions];
        [serializer writeElement:kCustomIconDataElementName text:b64]; 
    }
    
    if ( self.name.length ) {
        if ( ![serializer writeElement:kNameElementName text:self.name] ) return NO;
    }
    
    if ( self.modified ) {
        if ( ![serializer writeElement:kLastModificationTimeElementName date:self.modified] ) return NO;
    }

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];

    return YES;
}

@end
