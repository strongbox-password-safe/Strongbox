#import <Foundation/Foundation.h>
#import "KeePassDatabase.h"
#import "Utils.h"
#import "Utils.h"
#import "PwSafeSerialization.h"
#import "KdbxSerialization.h"
#import "RootXmlDomainObject.h"
#import "KeePassXmlParserDelegate.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePassConstants.h"
#import "XmlTreeSerializer.h"
#import "AttachmentsRationalizer.h"
#import "KdbxSerializationCommon.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

static const BOOL kLogVerbose = NO;

@interface KeePassDatabase ()

@property (nonatomic) RootXmlDomainObject* existingRootXmlDocument;
@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* existingExtraUnknownHeaders;

@end

@implementation KeePassDatabase

+ (NSString *)fileExtension {
    return @"kdbx";
}

- (NSString *)fileExtension {
    return [KeePassDatabase fileExtension];
}

- (DatabaseFormat)format {
    return kKeePass;
}

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [KdbxSerialization isAValidSafe:candidate];
}

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
        
        _attachments = [NSMutableArray array];
        _customIcons = [NSMutableDictionary dictionary];
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
        
        //NSLog(@"%@", serializationData.xml);
        
        self.existingRootXmlDocument = parseKeePassXml(serializationData.innerRandomStreamId,
                                                       serializationData.protectedStreamKey,
                                                       XmlProcessingContext.standardV3Context,
                                                       serializationData.xml,
                                                       ppError);
        
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
        _rootGroup = [xmlStrongboxModelAdaptor fromXmlModelToStrongboxModel:self.existingRootXmlDocument error:ppError];
        
        if(_rootGroup == nil) {
            NSLog(@"Error converting Xml model to Strongbox model: [%@]", *ppError);
            return nil;
        }

        // 5. Get Attachments
        
        NSArray<V3Binary*>* v3Binaries = safeGetBinaries(self.existingRootXmlDocument);

        _attachments = [NSMutableArray array];

        NSArray *sortedById = [v3Binaries sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [@(((V3Binary*)obj1).id) compare:@(((V3Binary*)obj2).id)];
        }];
        
        for (V3Binary* binary in sortedById) {
            DatabaseAttachment* dbA = [[DatabaseAttachment alloc] init];
            dbA.data = binary.data;
            dbA.compressed = binary.compressed;
            [_attachments addObject:dbA];
        }
        
        if(kLogVerbose) {
            NSLog(@"Attachments: %@", self.attachments);
        }
        
        // 6.
        
        _customIcons = safeGetCustomIcons(self.existingRootXmlDocument);
        
        // 7. Metadata
    
        _metadata = [[KeePassDatabaseMetadata alloc] init];
        
        if(self.existingRootXmlDocument.keePassFile.meta.generator.text) {
            self.metadata.generator = self.existingRootXmlDocument.keePassFile.meta.generator.text;
        }
        
        self.metadata.transformRounds = serializationData.transformRounds;
        self.metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
        self.metadata.compressionFlags = serializationData.compressionFlags;
        self.metadata.version = serializationData.fileVersion;
        self.metadata.cipherUuid = serializationData.cipherId;
        
        self.existingExtraUnknownHeaders = serializationData.extraUnknownHeaders;
        self.masterPassword = password;
    }
    
    return self;
}

static NSMutableDictionary<NSUUID*, NSData*>* safeGetCustomIcons(RootXmlDomainObject* root) {
    if(root && root.keePassFile && root.keePassFile.meta && root.keePassFile.meta.customIconList) {
        if(root.keePassFile.meta.customIconList.icons) {
            NSArray<CustomIcon*> *icons = root.keePassFile.meta.customIconList.icons;
            NSMutableDictionary<NSUUID*, NSData*> *ret = [NSMutableDictionary dictionaryWithCapacity:icons.count];
            for (CustomIcon* icon in icons) {
                [ret setObject:icon.data forKey:icon.uuid];
            }
            return ret;
        }
    }
    
    return [NSMutableDictionary dictionary];
}

static NSMutableArray<V3Binary*>* safeGetBinaries(RootXmlDomainObject* root) {
    if(root && root.keePassFile && root.keePassFile.meta && root.keePassFile.meta.v3binaries) {
        return root.keePassFile.meta.v3binaries.binaries;
    }
    
    return [NSMutableArray array];
}

///////////////////////////////////////////////////////////////////////////////

- (NSData *)getAsData:(NSError**)error {
    if(!self.masterPassword) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }
    
    // 1. Attachments - Rationalise. This needs to come first in case we change the attachments list / and node references
    
    _attachments = [[AttachmentsRationalizer rationalizeAttachments:self.attachments root:self.rootGroup] mutableCopy];
    
    // 2. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:self.rootGroup
                                                                        customIcons:self.customIcons
                                                            existingRootXmlDocument:self.existingRootXmlDocument
                                                                            context:[XmlProcessingContext standardV3Context]
                                                                              error:error];
    
    if(!rootXmlDocument) {
        NSLog(@"Could not convert Database to Xml Model.");
        if(error) {
            *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        }
        
        return nil;
    }
    
    // 3. Add Attachments to Xml Doc
    
    if(!rootXmlDocument.keePassFile.meta.v3binaries) {
        rootXmlDocument.keePassFile.meta.v3binaries = [[V3BinariesList alloc] initWithContext:[XmlProcessingContext standardV3Context]];
    }
    
    NSMutableArray<V3Binary*>* v3Binaries = rootXmlDocument.keePassFile.meta.v3binaries.binaries;
    [v3Binaries removeAllObjects];
    
    int i = 0;
    for (DatabaseAttachment* binary in self.attachments) {
        V3Binary* bin = [[V3Binary alloc] initWithContext:[XmlProcessingContext standardV3Context]];
        bin.compressed = binary.compressed;
        bin.data = binary.data;
        bin.id = i++;
        [v3Binaries addObject:bin];
    }
    
    // 4. We need to calculate the header hash unfortunately before we generate the xml blob, and set it in the Xml
    
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
    serializationData.cipherId = self.metadata.cipherUuid;
    
    KdbxSerialization *kdbxSerializer = [[KdbxSerialization alloc] init:serializationData];
    
    // Set Header Hash
    
    NSString *headerHash = [kdbxSerializer stage1Serialize:self.masterPassword error:error];
    if(!headerHash) {
        NSLog(@"Could not serialize Document to KDBX. Stage 1");
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX. Stage 1." errorCode:-6];
        }
        
        return nil;
    }
    
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
    
    NSData *data = [kdbxSerializer stage2Serialize:xml error:error];
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX." errorCode:-6];
        }
        
        return nil;
    }
    
    return data;
}

- (NSString * _Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return [self description];
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
