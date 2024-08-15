//
//  KeePassXmlParser.m
//  Strongbox
//
//  Created by Mark on 11/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassXmlParser.h"
#import "RootXmlDomainObject.h"
#import "InnerRandomStream.h"
#import "XmlProcessingContext.h"
#import "KeePassConstants.h"
#import "InnerRandomStreamFactory.h"
#import "Utils.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "NSData+GZIP.h"

@interface KeePassXmlParser ()

@property NSMutableArray<id<XmlParsingDomainObject>> *handlerStack;
@property (nonatomic) id<InnerRandomStream> innerRandomStream;
@property (nonatomic) NSError *errorParse;
@property (nonatomic) NSError *problemDecrypting;
@property XmlProcessingContext* context;
@property NSMutableString* mutableText;
@property BOOL sanityCheckStreamDecryption;

@end

@implementation KeePassXmlParser

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(NSData *)protectedStreamKey
              sanityCheckStreamDecryption:(BOOL)sanityCheckStreamDecryption
                                  context:(XmlProcessingContext *)context {
    if(self = [super init]) {
        self.context = context;
                
        self.innerRandomStream = [InnerRandomStreamFactory getStream:innerRandomStreamId
                                                                 key:protectedStreamKey
                                                createNewKeyIfAbsent:NO];
        
        if (!self.innerRandomStream) {
            slog(@"WARNWARNWARN: Could not create inner stream cipher: [%d]-[%lu]-[%@]", innerRandomStreamId, (unsigned long)protectedStreamKey.length, protectedStreamKey);
            return nil;
        }
        
        self.sanityCheckStreamDecryption = sanityCheckStreamDecryption;
        self.handlerStack = [NSMutableArray array];
        [self.handlerStack addObject:[[RootXmlDomainObject alloc] initWithContext:context]];
        self.mutableText = [[NSMutableString alloc] initWithCapacity:32 * 1024]; 
    }
    
    return self;
}

- (RootXmlDomainObject *)rootElement {
    if(self.errorParse) {
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

- (void)foundCharacters:(NSString *)string {
    id<XmlParsingDomainObject> currentHandler = [self.handlerStack lastObject];

    BOOL protected = NO;
    
    if ( currentHandler.originalAttributes &&
        (currentHandler.originalAttributes[kAttributeProtected] )) {
        NSString* protectedString = currentHandler.originalAttributes[kAttributeProtected];
        protected = protectedString.isKeePassXmlBooleanStringTrue;
    }
    
    if ( currentHandler.isV3BinaryHack && !protected ) { 
        BOOL streamOk = [currentHandler appendStreamedText:string];
        if (!streamOk) {
            self.errorParse = [Utils createNSError:@"Error during foundCharacters streaming" errorCode:-1];
        }
    }
    else {
        [self.mutableText appendString:string];
    }
}

- (void)didEndElement:(NSString *)elementName {
    id<XmlParsingDomainObject> completedObject = [self.handlerStack lastObject];
    [self.handlerStack removeLastObject];
    
    
    
    if (self.mutableText.length) {
        BOOL protected = NO;
        
        if ( completedObject.originalAttributes &&
            (completedObject.originalAttributes[kAttributeProtected] )) {
            NSString* protectedString = completedObject.originalAttributes[kAttributeProtected];
            protected = protectedString.isKeePassXmlBooleanStringTrue;
        }
        
        if(protected) {
            NSString *string = self.mutableText;
            
            if ( completedObject.isV3BinaryHack ) {
                V3Binary* v3Binary = (V3Binary*)completedObject;
                
                NSData* data = [self decryptProtectedToData:string];
        
                BOOL compressed = NO;
                if ( completedObject.originalAttributes &&
                    (completedObject.originalAttributes[kBinaryCompressedAttribute] )) {
                    NSString* compressedString = completedObject.originalAttributes[kBinaryCompressedAttribute];
                    compressed = compressedString.isKeePassXmlBooleanStringTrue;
                }

                NSData* decompressed = compressed ? data.gunzippedData : data;
                [v3Binary onCompletedWithStrangeProtectedAttribute:decompressed];
            }
            else {
                NSString* decrypted = [self decryptProtectedToString:string];
            
                if (self.sanityCheckStreamDecryption && !decrypted) {
                    slog(@"🔴 WARN: Could not decrypt CipherText...");
                    
                    NSString *msg = [NSString stringWithFormat:@"Strongbox could not decrypt protected text. This field is likely corrupt."];
                    self.problemDecrypting = [Utils createNSError:msg errorCode:-1];
                    [completedObject setXmlText:@"CORRUPT_PROTECTED_FIELD"];
                }
                else {
                    [completedObject setXmlText:decrypted];
                }
            }
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
                slog(@"WARN: Unknown Object Type but not BaseDictionaryHandler?!");
                self.errorParse = [Utils createNSError:@"Unknown Object Type but not BaseDictionaryHandler." errorCode:-1];
            }
            else {
                BaseXmlDomainObjectHandler *bdh = completedObject;
                [parentObject addUnknownChildObject:bdh];
            }
        }
    }
    else {
        slog(@"WARN: No Handler on stack available for element! Unbalanced XML?");
        self.errorParse = [Utils createNSError:@"No Handler on stack available for element! Unbalanced XML." errorCode:-1];
    }
}

- (NSData*)decryptProtectedToData:(NSString*)ct {
    NSData *ctData = [[NSData alloc] initWithBase64EncodedString:ct options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSData* plaintext = [self.innerRandomStream doTheXor:ctData];

    return plaintext;
}

- (NSString*)decryptProtectedToString:(NSString*)ct {
    if(self.innerRandomStream == nil) { 
        return ct;
    }
    
    NSData* plaintext = [self decryptProtectedToData:ct];

    NSString* ret = [[NSString alloc] initWithData:plaintext encoding:NSUTF8StringEncoding];
    
    if (self.sanityCheckStreamDecryption) {
        if (ct.length && ret.length == 0) {
            slog(@"WARNWARN - Decrypting Ciphertext led to null or empty string - likely incorrect key: [%@] => [%@]", ct, ret);
            return nil;
        }
    }
    
    return ret;
}

- (NSError *)decryptionProblem {
    return self.problemDecrypting;
}

- (NSError*)error {
    return self.errorParse;
}

@end
