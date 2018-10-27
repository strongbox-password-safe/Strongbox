#import <Foundation/Foundation.h>
#import "KeePassDatabase.h"
#import "Utils.h"
#import "BinaryParsingHelper.h"
#import "SafeTools.h"
#import "KdbxSerialization.h"
#import "RootXmlDomainObject.h"
#import "KeePassXmlParserDelegate.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePassConstants.h"
#import "XmlTreeSerializer.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface KeePassDatabase ()

@property (nonatomic) RootXmlDomainObject* existingRootXmlDocument;
@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* existingExtraUnknownHeaders;

@end

@implementation KeePassDatabase

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
        _rootGroup = [[Node alloc] initAsRoot:nil];
        
        // Keepass has it's own root group to work off of, and doesn't allow entries at the actual root.
        // In the UI we don't display the actual root but the Keepass Root
        
        Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:_rootGroup uuid:nil];
        [_rootGroup addChild:keePassRootGroup];
        
        _metadata = [[KeePassDatabaseMetadata alloc] init];
        
        self.existingRootXmlDocument = nil;
        self.existingExtraUnknownHeaders = nil;
        self.masterPassword = password;
        
        return self;
    }
    else {
        return nil;
    }
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError
{
    return [self initExistingWithDataAndPassword:safeData password:password ignoreHeaderHash:NO error:ppError];
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                               ignoreHeaderHash:(BOOL)ignoreHeaderHash
                                          error:(NSError **)ppError {
    if (self = [super init]) {
        // 1. First get XML out of the encrypted binary...
        
        SerializationData *serializationData = [KdbxSerialization deserialize:safeData password:password ppError:ppError];
        
        if(serializationData == nil) {
            NSLog(@"Error getting Decrypting KDBX binary: [%@]", *ppError);
            return nil;
        }
        
        // 2. Convert the Xml to a more usable Xml Model
        
        NSLog(@"%@", serializationData.xml);
        
        self.existingRootXmlDocument = [self parseKeePassXml:serializationData error:ppError];
        if(self.existingRootXmlDocument == nil) {
            NSLog(@"Error getting parseKeePassXml: [%@]", *ppError);
            return nil;
        }
        
        // 3. Verify Header Hash if present
        
        if(!ignoreHeaderHash && self.existingRootXmlDocument.keePassFile.meta.headerHash) {
            if(![self.existingRootXmlDocument.keePassFile.meta.headerHash.text isEqualToString:serializationData.headerHash]) {
                NSLog(@"Header Hash mismatch. Document has been corrupted or interfered with: [%@] != [%@]",
                      serializationData.headerHash,
                      self.existingRootXmlDocument.keePassFile.meta.headerHash.text);
                
                if(ppError != nil) {
                    *ppError = [Utils createNSError:@"Header Hash incorrect. Document has been corrupted." errorCode:-3];
                }
                
                return nil;
            }
        }
        
        // 4. Convert the Xml Model to the Strongbox Model
        
        XmlStrongBoxModelAdaptor *xmlStrongboxModelAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
        KeepassMetaDataAndNodeModel *metadataAndNodeModel = [xmlStrongboxModelAdaptor fromXmlModelToStrongboxModel:self.existingRootXmlDocument error:ppError];
        
        if(metadataAndNodeModel == nil) {
            NSLog(@"Error converting Xml model to Strongbox model: [%@]", *ppError);
            return nil;
        }

        _rootGroup = metadataAndNodeModel.rootNode;
        _metadata = metadataAndNodeModel.metadata;

        self.metadata.transformRounds = serializationData.transformRounds;
        self.metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
        self.metadata.compressionFlags = serializationData.compressionFlags;
        self.metadata.version = serializationData.fileVersion;
        
        self.existingExtraUnknownHeaders = serializationData.extraUnknownHeaders;
        self.masterPassword = password;
    }
    
    return self;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [KdbxSerialization isAValidSafe:candidate];
}

///////////////////////////////////////////////////////////////////////////////

- (NSData *)getAsData:(NSError**)error {
    if(!self.masterPassword) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }
    
    // 1. From Strongbox to Xml Model
    
    KeepassMetaDataAndNodeModel *nodeAndMetadata = [[KeepassMetaDataAndNodeModel alloc] initWithMetadata:self.metadata
                                                                                               nodeModel:self.rootGroup];
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:nodeAndMetadata
                                                            existingRootXmlDocument:self.existingRootXmlDocument
                                                                              error:error];
    
    if(!rootXmlDocument) {
        NSLog(@"Could not convert Database to Xml Model.");
        if(error) {
            *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        }
        
        return nil;
    }
    
    // 2. We need to calculate the header hash unfortunately before we generate the xml blob, and set it in the Xml
    
    XmlTreeSerializer *xmlSerializer = [[XmlTreeSerializer alloc] initWithProtectedStreamId:self.metadata.innerRandomStreamId
                                                                                        key:nil // Auto generated new key
                                                                                prettyPrint:NO];
    
    SerializationData *serializationData = [[SerializationData alloc] init];
    
    serializationData.protectedStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = self.existingExtraUnknownHeaders;
    serializationData.compressionFlags = self.metadata.compressionFlags;
    serializationData.innerRandomStreamId = self.metadata.innerRandomStreamId;
    serializationData.transformRounds = self.metadata.transformRounds;
    serializationData.fileVersion = self.metadata.version;
    
    KdbxSerialization *kdbxSerializer = [[KdbxSerialization alloc] init:serializationData];
    
    // Set Header Hash
    
    NSString *headerHash = [kdbxSerializer stage1Serialize:self.masterPassword];
    [rootXmlDocument.keePassFile.meta setHash:headerHash];
    
    // 3. From Xml Model to Xml String (including inner stream encryption)
   
    XmlTree* xmlTree = [rootXmlDocument generateXmlTree];
    NSString *xml = [xmlSerializer serializeTrees:xmlTree.children];
    
    // NSLog(@"Serializing XML Document:\n%@", xml);
    
    if(!xml) {
        NSLog(@"Could not serialize Xml to Document.");
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        }
        
        return nil;
    }
    
    // 3. KDBX serialize this Xml Document...
    
    NSData *data = [kdbxSerializer stage2Serialize:xml];
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX." errorCode:-6];
        }
        
        return nil;
    }
    
    return data;
}

- (RootXmlDomainObject*)parseKeePassXml:(SerializationData*)serializationData error:(NSError**)error{
    //NSLog(@"Parsing Xml Document:\n%@", serializationData.xml);
    
    KeePassXmlParserDelegate *parserDelegate =
    [[KeePassXmlParserDelegate alloc] initWithProtectedStreamId:serializationData.innerRandomStreamId
                                                            key:serializationData.protectedStreamKey];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[serializationData.xml dataUsingEncoding:NSUTF8StringEncoding]];
    [parser setDelegate:parserDelegate];
    [parser parse];
    NSError* err = [parser parserError];
    
    if(err)
    {
        NSLog(@"ERROR: %@", err);
        if(error) {
            *error = err;
        }
        return nil;
    }
    
    RootXmlDomainObject* rootDocument = parserDelegate.rootElement;

    return rootDocument;
}

- (NSString * _Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return [self description];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
