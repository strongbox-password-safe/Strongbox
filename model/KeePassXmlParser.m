//
//  KeePassXmlParser.m
//  Strongbox
//
//  Created by Mark on 11/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "KeePassXmlParser.h"
#import "RootXmlDomainObject.h"
#import "InnerRandomStream.h"
#import "XmlProcessingContext.h"
#import "KeePassConstants.h"
#import "InnerRandomStreamFactory.h"

@interface KeePassXmlParser ()

@property NSMutableArray<id<XmlParsingDomainObject>> *handlerStack;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;
@property (nonatomic) BOOL errorParsing;
@property XmlProcessingContext* context;
@property NSMutableString* mutableText;

@end

@implementation KeePassXmlParser

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
        self.mutableText = [[NSMutableString alloc] initWithCapacity:32 * 1024]; // Too High/Low?
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

- (void)didStartElement:(NSString *)elementName
             attributes:(NSDictionary *)attributeDict {
    id<XmlParsingDomainObject> nextHandler = [[self.handlerStack lastObject] getChildHandler:elementName];
    
    if(!nextHandler) {
        nextHandler = [[BaseXmlDomainObjectHandler alloc] initWithXmlElementName:elementName context:self.context];
    }
    
    [nextHandler setXmlInfo:elementName attributes:attributeDict];
    
    if(self.mutableText.length) {
        [self.mutableText setString:@""];
    }
    
    [self.handlerStack addObject:nextHandler];
}

-(void)foundCharacters:(NSString *)string {
    [self.mutableText appendString:string];
}

- (void)didEndElement:(NSString *)elementName {
    id<XmlParsingDomainObject> completedObject = [self.handlerStack lastObject];
    [self.handlerStack removeLastObject];
    
    // Decrypt Now that we have the full text if necessary
    
    if (self.mutableText.length) {
        BOOL protected = completedObject.originalAttributes &&
        (completedObject.originalAttributes[kAttributeProtected] &&
         ([completedObject.originalAttributes[kAttributeProtected] isEqualToString:kAttributeValueTrue]));
        
        if(protected) {
            NSString *string = self.mutableText;
            NSString* decrypted = [self decryptProtected:string];
            [completedObject setXmlText:decrypted];
        }
        else {
            [completedObject setXmlText:self.mutableText.copy];
        }
        
        [self.mutableText setString:@""];
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
                [parentObject addUnknownChildObject:bdh];
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
