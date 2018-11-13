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
#import "KeePassDatabase.h"
#import "InnerRandomStreamFactory.h"

@interface KeePassXmlParserDelegate ()

@property NSMutableArray<id<XmlParsingDomainObject>> *handlerStack;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;
@property (nonatomic) BOOL errorParsing;
@property XmlProcessingContext* context;

@end

@implementation KeePassXmlParserDelegate

- (instancetype)initV3Plaintext  {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil context:[XmlProcessingContext standardV3Context]];
}

- (instancetype)initV4Plaintext  {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil context:[XmlProcessingContext standardV4Context]];
}

- (instancetype)initPlaintext:(XmlProcessingContext*)context  {
    return [self initWithProtectedStreamId:kInnerStreamPlainText key:nil context:context];
}

- (instancetype)initV3WithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
{
    return [self initWithProtectedStreamId:innerRandomStreamId key:protectedStreamKey context:[XmlProcessingContext standardV3Context]];
}

- (instancetype)initV4WithProtectedStreamId:(uint32_t)innerRandomStreamId
                                        key:(nullable NSData*)protectedStreamKey
{
    return [self initWithProtectedStreamId:innerRandomStreamId key:protectedStreamKey context:[XmlProcessingContext standardV4Context]];
}

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
                                  context:(XmlProcessingContext*)context {
    if(self = [super init]) {
        self.context = context;
        self.innerRandomStream = [InnerRandomStreamFactory getStream:innerRandomStreamId key:protectedStreamKey];
        self.handlerStack = [NSMutableArray array];
        [self.handlerStack addObject:[[RootXmlDomainObject alloc] initWithContext:context]];
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
        nextHandler = [[BaseXmlDomainObjectHandler alloc] initWithXmlElementName:elementName context:self.context];
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
    
    NSData *ctData = [[NSData alloc] initWithBase64EncodedString:ct options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSData* plaintext = [self.innerRandomStream xor:ctData];
    
    return [[NSString alloc] initWithData:plaintext encoding:NSUTF8StringEncoding];
}

@end
