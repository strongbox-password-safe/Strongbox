//
//  KeePassXmlParserDelegate.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassXmlParserDelegate.h"
#import "XmlParsingDomainObject.h"
#import "BaseXmlDomainObjectHandler.h"
#import "Salsa20Stream.h"
#import <CommonCrypto/CommonDigest.h>
#import "KeePassDatabase.h"

@interface KeePassXmlParserDelegate ()

@property NSMutableArray<id<XmlParsingDomainObject>> *handlerStack;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;
@property (nonatomic) BOOL errorParsing;

@end

@implementation KeePassXmlParserDelegate

- (instancetype)initPlaintext {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                        key:(nullable NSData*)protectedStreamKey {
    if(self = [super init]) {
        // TODO: This same code is in XmlTreeSerializer. Move to a common RandomStream Factory
        if(innerRandomStreamId == kInnerStreamSalsa20) {
            const uint8_t iv[] = {0xE8, 0x30, 0x09, 0x4B, 0x97, 0x20, 0x5D, 0x2A};
            self.innerRandomStream = [[Salsa20Stream alloc] initWithIv:iv key:protectedStreamKey];
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
        
        self.handlerStack = [NSMutableArray array];
        [self.handlerStack addObject:[[RootXmlDomainObject alloc] init]];
    }

    return self;
}

- (RootXmlDomainObject *)rootElement {
    if(self.errorParsing) {
        return nil;
    }
    
    id<XmlParsingDomainObject> rootHandler = [self.handlerStack firstObject];

    if(![rootHandler isKindOfClass:[RootXmlDomainObject class]]) {
        return nil;
    }
    
    return (RootXmlDomainObject*)rootHandler;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    id<XmlParsingDomainObject> nextHandler = [[self.handlerStack lastObject] getChildHandler:elementName];
    
    if(!nextHandler) {
        nextHandler = [[BaseXmlDomainObjectHandler alloc] initWithXmlElementName:elementName];
    }
    
    [nextHandler setXmlInfo:elementName attributes:attributeDict];
    
    [self.handlerStack addObject:nextHandler];
}

-(void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    id<XmlParsingDomainObject> handler = [self.handlerStack lastObject];
    
    [handler appendXmlText:string]; // Can be called multiple times
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    id<XmlParsingDomainObject> completedObject = [self.handlerStack lastObject];
    [self.handlerStack removeLastObject];

    NSDictionary *attributeDict = completedObject.nonCustomisedXmlTree.node.xmlAttributes;

    // Decrypt Now that we have the full text if necessary
    
    if([attributeDict objectForKey:kAttributeProtected] && ([[attributeDict objectForKey:kAttributeProtected] isEqualToString:kAttributeValueTrue])) {
        NSString *string = [completedObject getXmlText];
        
        NSString* decrypted = [self decryptProtected:string];
        
        [completedObject setXmlText:decrypted];
    }
    
    [completedObject onCompleted];

    id<XmlParsingDomainObject> parentObject = [self.handlerStack lastObject];
    
    if(parentObject) {
        BOOL knownObjectType = [parentObject addKnownChildObject:completedObject withXmlElementName:elementName];
        
        if(!knownObjectType) {
            if(![completedObject isKindOfClass:[BaseXmlDomainObjectHandler class]]) {
                NSLog(@"WARN: Unknown Object Type but not BaseDictionaryHandler?!");
                self.errorParsing = YES;
            }
            else {
                BaseXmlDomainObjectHandler *bdh = completedObject;
                [parentObject addUnknownChildObject:bdh.nonCustomisedXmlTree];
            }
        }
    }
    else {
        NSLog(@"WARN: No Handler on stack available for element! Unbalanced XML?");
        self.errorParsing = YES;
    }
}

- (NSString*)decryptProtected:(NSString*)ct {
    if(self.innerRandomStream == nil) { // Plaintext or for testing
        return ct;
    }
    
    NSData *ctData = [[NSData alloc] initWithBase64EncodedString:ct options:kNilOptions];
    
    NSData* plaintext = [self.innerRandomStream xor:ctData];
    
    return [[NSString alloc] initWithData:plaintext encoding:NSUTF8StringEncoding];
}

@end
