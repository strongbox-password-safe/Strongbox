//
//  XmlTreeSerializer.m
//  Strongbox
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "XmlSerializer.h"
#import "XMLWriter.h"
#import "KeePassDatabase.h"
#import "InnerRandomStreamFactory.h"
#import "Utils.h"
#import "SimpleXmlValueExtractor.h"
#import "XmlOutputStreamWriter.h"

@interface XmlSerializer ()

@property (nonatomic) XMLWriter* xmlWriter;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;
@property BOOL v4Format;

@end

@implementation XmlSerializer

- (instancetype)initWithPrettyPrint:(BOOL)prettyPrint v4Format:(BOOL)v4Format {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil v4Format:v4Format prettyPrint:prettyPrint];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                    b64ProtectedStreamKey:(NSString*)b64ProtectedStreamKey
                                 v4Format:(BOOL)v4Format
                              prettyPrint:(BOOL)prettyPrint {
    NSData *key = [[NSData alloc] initWithBase64EncodedString:b64ProtectedStreamKey options:NSDataBase64DecodingIgnoreUnknownCharacters];

    return [self initWithProtectedStreamId:innerRandomStreamId key:key v4Format:v4Format prettyPrint:prettyPrint];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)key
                                 v4Format:(BOOL)v4Format
                              prettyPrint:(BOOL)prettyPrint {
    return [self initWithProtectedStream:[InnerRandomStreamFactory getStream:innerRandomStreamId key:key] v4Format:v4Format prettyPrint:prettyPrint];
}

- (instancetype)initWithProtectedStream:(id<InnerRandomStream>)innerRandomStream
                                 v4Format:(BOOL)v4Format
                              prettyPrint:(BOOL)prettyPrint {
    return [self initWithProtectedStream:innerRandomStream v4Format:v4Format prettyPrint:prettyPrint outputStream:nil];
}

- (instancetype)initWithProtectedStream:(id<InnerRandomStream>)innerRandomStream v4Format:(BOOL)v4Format prettyPrint:(BOOL)prettyPrint outputStream:(NSOutputStream *)outputStream {
    if( self = [super init] ) {
        self.innerRandomStream = innerRandomStream;
        self.v4Format = v4Format;
        
        if ( outputStream ) {
            self.xmlWriter = [[XmlOutputStreamWriter alloc] initWithOutputStream:outputStream];
        }
        else {
            self.xmlWriter = [[XMLWriter alloc] init];
        }
        
        if(prettyPrint) {
            [self.xmlWriter setPrettyPrinting:@"\t" withLineBreak:@"\n"];
        }
        
        [self.xmlWriter setAutomaticEmptyElements:YES];
    }
    
    return self;
}

- (void)beginDocument {
    [self.xmlWriter writeStartDocumentWithEncodingAndVersion:@"UTF-8" version:@"1.0"];
}

- (void)endDocument {
    [self.xmlWriter writeEndDocument];
}

- (BOOL)beginElement:(NSString*)elementName {
    if(!elementName.length) {
        slog(@"Null/Empty Element name found at [%@]. Error.", elementName);
        return NO;
    }

    [self.xmlWriter writeStartElement:elementName];
    return YES;
}

- (BOOL)beginElement:(NSString *)elementName text:(NSString *)text attributes:(NSDictionary *)attributes {
    if (![self beginElement:elementName]) {
        return NO;
    }
    
    [self writeAttributes:attributes];
    
    BOOL protected = attributes ? [attributes[kAttributeProtected] isEqualToString:kAttributeValueTrue] : NO;

    [self writeText:text protected:protected];
    
    return YES;
}

- (BOOL)writeElement:(NSString *)elementName integer:(NSInteger)integer {
    return [self writeElement:elementName text:@(integer).stringValue];
}

- (BOOL)writeElement:(NSString *)elementName date:(NSDate *)date {
    if(!date) {
        return YES;
    }
    
    NSString* dateString;
    if(self.v4Format) {
        dateString = [SimpleXmlValueExtractor getV4String:date];
    }
    else {
        dateString = [SimpleXmlValueExtractor getV3String:date];
    }

    return [self writeElement:elementName text:dateString];
}

- (BOOL)writeElement:(NSString *)elementName boolean:(BOOL)boolean {
    return [self writeElement:elementName text:boolean ? kAttributeValueTrue : kAttributeValueFalse];
}

- (BOOL)writeElement:(NSString *)elementName uuid:(NSUUID *)uuid {
    if(!uuid) {
        return YES;
    }
    
    uuid_t rawUuid;
    [uuid getUUIDBytes:(uint8_t*)&rawUuid];
    NSData *dataUuid = [NSData dataWithBytes:&rawUuid length:sizeof(uuid_t)];
    NSString* uuidString = [dataUuid base64EncodedStringWithOptions:kNilOptions];

    return [self writeElement:elementName text:uuidString];
}

- (BOOL)writeElement:(NSString*)elementName text:(NSString*)text {
    return [self writeElement:elementName text:text protected:NO trimWhitespace:NO];
}

- (BOOL)writeElement:(NSString *)elementName
                text:(NSString *)text
           protected:(BOOL)protected
      trimWhitespace:(BOOL)trimWhitespace {
    return [self writeElement:elementName
                         text:text
                   attributes:protected ? @{ kAttributeProtected : kAttributeValueTrue } : nil
               trimWhitespace:trimWhitespace];
}

- (BOOL)writeElement:(NSString *)elementName text:(NSString *)text attributes:(NSDictionary *)attributes {
    return [self writeElement:elementName text:text attributes:attributes trimWhitespace:YES];
}

- (BOOL)writeElement:(NSString *)elementName
                text:(NSString *)text
          attributes:(NSDictionary *)attributes
      trimWhitespace:(BOOL)trimWhitespace {
    if(![self beginElement:elementName]) {
        return NO;
    }
    
    [self writeAttributes:attributes];
    
    BOOL protected = attributes ? [attributes[kAttributeProtected] isEqualToString:kAttributeValueTrue] : NO;
    
    [self writeText:text protected:protected trimWhitespace:trimWhitespace];
    
    [self endElement];
    
    return YES;
}

- (void)writeAttributes:(NSDictionary<NSString*, NSString*>*)attributes {
    if(!attributes) {
        return;
    }
        
    for (NSString* key in attributes.allKeys) {
        [self.xmlWriter writeAttribute:key value:attributes[key]];
    }
}

- (void)writeText:(NSString*)text protected:(BOOL)protected {
    [self writeText:text protected:protected trimWhitespace:YES];
}

- (void)writeText:(NSString*)text protected:(BOOL)protected trimWhitespace:(BOOL)trimWhitespace {
    if(text.length) {
        if(protected) {
            NSString *encrypted = [self encryptProtected:text];
            [self.xmlWriter writeCharacters:encrypted];
        }
        else {
            if(!trimWhitespace) {
                [self.xmlWriter writeCharacters:text];
            }
            else {
                NSString* trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if(trimmed.length) {
                    [self.xmlWriter writeCharacters:trimmed];
                }
            }
        }
    }
}

- (void)endElement {
    [self.xmlWriter writeEndElement];
}



- (NSString *)encryptProtected:(NSString *)pt {
    if(self.innerRandomStream == nil) { 
        return pt;
    }
    
    @autoreleasepool {
        NSData *ptData = [pt dataUsingEncoding:NSUTF8StringEncoding];

        NSData* ciphertext = [self.innerRandomStream doTheXor:ptData];
        
        return [ciphertext base64EncodedStringWithOptions:kNilOptions];
    }
}
    
- (NSData *)protectedStreamKey {
    return self.innerRandomStream == nil ? nil : self.innerRandomStream.key;
}

- (NSString *)xml {
    return self.xmlWriter.toString;
}

- (NSError *)streamError {
    return self.xmlWriter.streamError;
}

@end
