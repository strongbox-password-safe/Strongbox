//
//  XmlTreeSerializer.m
//  Strongbox
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlTreeSerializer.h"
#import "XmlTree.h"
#import "XMLWriter.h"
#import "KeePassDatabase.h"
#import "Salsa20Stream.h"

@interface XmlTreeSerializer ()

@property (nonatomic) XMLWriter* xmlWriter;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;

@end

@implementation XmlTreeSerializer

- (instancetype)initWithPrettyPrint:(BOOL)prettyPrint {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil prettyPrint:prettyPrint];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                    b64ProtectedStreamKey:(NSString*)b64ProtectedStreamKey
                              prettyPrint:(BOOL)prettyPrint {
    NSData *key = [[NSData alloc] initWithBase64EncodedString:b64ProtectedStreamKey options:kNilOptions];

    return [self initWithProtectedStreamId:innerRandomStreamId key:key prettyPrint:prettyPrint];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)key
                              prettyPrint:(BOOL)prettyPrint {
    // TODO: This same code is in Xml Parser. Move to a common RandomStream Factory
    if(self = [super init]) {
        if(innerRandomStreamId == kInnerStreamSalsa20) {
            if(!key) {
                key = [Salsa20Stream generateNewKey];
            }
            
            const uint8_t iv[] = {0xE8, 0x30, 0x09, 0x4B, 0x97, 0x20, 0x5D, 0x2A};
            self.innerRandomStream = [[Salsa20Stream alloc] initWithIv:iv key:key];
        }
        else if (innerRandomStreamId == kInnerStreamArc4) {
            // TODO: Support this for older DBs?
            return nil;
        }
        else if (innerRandomStreamId == kInnerChaCha20) {
            // TODO: believe this is for KDBX 4+ ?
            return nil;
        }
        else if (innerRandomStreamId == kInnerStreamPlainText) {
            self.innerRandomStream = nil;
        }
        else {
            NSLog(@"Unknown innerRandomStreamId = %d", innerRandomStreamId);
            return nil;
        }
        
        self.xmlWriter = [[XMLWriter alloc] init];
        
        if(prettyPrint) {
            [self.xmlWriter setPrettyPrinting:@"    " withLineBreak:@"\n"];
        }
    }
    
    return self;
}

- (NSString*)serializeTrees:(NSArray<XmlTree*>*)trees {
    [self.xmlWriter writeStartDocumentWithEncodingAndVersion:@"UTF-8" version:@"1.0"];

    for (XmlTree* child in trees) {
        if(![self writeTree:child]) {
            return nil;
        }
    }

    [self.xmlWriter writeEndDocument];

    return [self.xmlWriter toString];
}

- (NSString*)serializeTree:(XmlTree*)tree {
    [self.xmlWriter writeStartDocumentWithEncodingAndVersion:@"UTF-8" version:@"1.0"];
    
    if(![self writeTree:tree]) {
        return nil;
    }
    
    [self.xmlWriter writeEndDocument];
    
    return [self.xmlWriter toString];
}

- (BOOL)writeTree:(XmlTree*)tree {
    if(!tree.node.xmlElementName.length) {
        NSLog(@"Null/Empty Element name found at [%@]. Error.", tree);
        return NO;
    }
    
    [self.xmlWriter writeStartElement:tree.node.xmlElementName];
    
    for (NSString* key in tree.node.xmlAttributes.allKeys) {
        [self.xmlWriter writeAttribute:key value:[tree.node.xmlAttributes objectForKey:key]];
    }
    
    if(tree.node.xmlText.length) {
        NSDictionary *attributeDict = tree.node.xmlAttributes;
        
        if([attributeDict objectForKey:kAttributeProtected] &&
           ([[attributeDict objectForKey:kAttributeProtected] isEqualToString:kAttributeValueTrue])) {
            NSString *encrypted = [self encryptProtected:tree.node.xmlText];
            
            [self.xmlWriter writeCharacters:encrypted];
        }
        else {
            [self.xmlWriter writeCharacters:tree.node.xmlText];
        }
    }
    
    for (XmlTree* child in tree.children) {
        if(![self writeTree:child]) {
            NSLog(@"Failed to write child of [%@]. Child = [%@] Error.", tree.node, child);
            return NO;
        }
    }
    
    [self.xmlWriter writeEndElement:tree.node.xmlElementName];
    
    return YES;
}

- (NSString*)encryptProtected:(NSString*)pt {
    if(self.innerRandomStream == nil) { // Plaintext or for testing
        return pt;
    }
    
    NSData *ptData = [pt dataUsingEncoding:NSUTF8StringEncoding];

    NSData* ciphertext = [self.innerRandomStream xor:ptData];
    
    return [ciphertext base64EncodedStringWithOptions:kNilOptions];
}
    
- (NSData *)protectedStreamKey {
    return self.innerRandomStream == nil ? nil : self.innerRandomStream.key;
}

@end
