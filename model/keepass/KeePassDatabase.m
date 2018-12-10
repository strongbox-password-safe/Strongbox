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
#import "KeePass2TagPackage.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface KeePassDatabase ()

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

- (StrongboxDatabase *)create:(NSString *)password {
    return [self create:password keyFileDigest:nil];
}

-(StrongboxDatabase *)create:(NSString *)password keyFileDigest:(nullable NSData *)keyFileDigest {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    // Keepass has it's own root group to work off of, and doesn't allow entries at the actual root.
    // In the UI we don't display the actual root but the Keepass Root
    
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:rootGroup uuid:nil];
    [rootGroup addChild:keePassRootGroup];
    
    KeePassDatabaseMetadata* metadata = [[KeePassDatabaseMetadata alloc] init];
    
    StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata masterPassword:password keyFileDigest:keyFileDigest];
    
    return ret;
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password error:(NSError **)error {
    return [self open:data password:password keyFileDigest:nil error:error];
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest error:(NSError **)error {
    // 1. First get XML out of the encrypted binary...
    
    SerializationData *serializationData = [KdbxSerialization deserialize:data password:password keyFileDigest:keyFileDigest ppError:error];
    
    if(serializationData == nil) {
        NSLog(@"Error getting Decrypting KDBX binary: [%@]", *error);
        return nil;
    }
    
    // 2. Convert the Xml to a more usable Xml Model
    
    //NSLog(@"%@", serializationData.xml);
    
    RootXmlDomainObject* xmlDoc = parseKeePassXml(  serializationData.innerRandomStreamId,
                                                           serializationData.protectedStreamKey,
                                                           XmlProcessingContext.standardV3Context,
                                                           serializationData.xml,
                                                           error);
    
    if(xmlDoc == nil) {
        NSLog(@"Error getting parseKeePassXml: [%@]", *error);
        return nil;
    }
    
    // 3. Verify Header Hash if present
    
    BOOL ignoreHeaderHash = NO;
    if(!ignoreHeaderHash && xmlDoc.keePassFile.meta.headerHash) {
        if(![xmlDoc.keePassFile.meta.headerHash.text isEqualToString:serializationData.headerHash]) {
            NSLog(@"Header Hash mismatch. Document has been corrupted or interfered with: [%@] != [%@]",
                  serializationData.headerHash,
                  xmlDoc.keePassFile.meta.headerHash.text);
            
            if(error != nil) {
                *error = [Utils createNSError:@"Header Hash incorrect. Document has been corrupted." errorCode:-3];
            }
            
            return nil;
        }
    }
    
    // 4. Convert the Xml Model to the Strongbox Model
    
    XmlStrongBoxModelAdaptor *xmlStrongboxModelAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    Node* rootGroup = [xmlStrongboxModelAdaptor fromXmlModelToStrongboxModel:xmlDoc error:error];
    
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", *error);
        return nil;
    }

    // 5. Get Attachments
    
    NSArray<DatabaseAttachment*>* attachments = getAttachments(xmlDoc);
    
    // 6.
    
    NSMutableDictionary<NSUUID*, NSData*>* customIcons = safeGetCustomIcons(xmlDoc);
    
    // 7. Metadata

    KeePassDatabaseMetadata *metadata = [[KeePassDatabaseMetadata alloc] init];
    
    if(xmlDoc.keePassFile.meta.generator.text) {
        metadata.generator = xmlDoc.keePassFile.meta.generator.text;
    }
    
    metadata.transformRounds = serializationData.transformRounds;
    metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
    metadata.compressionFlags = serializationData.compressionFlags;
    metadata.version = serializationData.fileVersion;
    metadata.cipherUuid = serializationData.cipherId;
    
    KeePass2TagPackage* adaptorTag = [[KeePass2TagPackage alloc] init];
    adaptorTag.unknownHeaders = serializationData.extraUnknownHeaders;
    adaptorTag.xmlDocument = xmlDoc;
    
    StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                           masterPassword:password
                                                            keyFileDigest:keyFileDigest
                                                              attachments:attachments
                                                              customIcons:customIcons];
    ret.adaptorTag = adaptorTag;
    
    return ret;
}

- (NSData *)save:(StrongboxDatabase *)database error:(NSError **)error {
    if(!database.masterPassword && !database.keyFileDigest) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }
    
    KeePass2TagPackage* adaptorTag = (KeePass2TagPackage*)database.adaptorTag;
    
    // 2. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *xmlDoc = [xmlAdaptor toXmlModelFromStrongboxModel:database.rootGroup
                                                                        customIcons:database.customIcons
                                                            existingRootXmlDocument:adaptorTag ? adaptorTag.xmlDocument : nil
                                                                            context:[XmlProcessingContext standardV3Context]
                                                                              error:error];
    
    if(!xmlDoc) {
        NSLog(@"Could not convert Database to Xml Model.");
        if(error) {
            *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        }
        
        return nil;
    }
    
    // 3. Add Attachments to Xml Doc
    
    if(!xmlDoc.keePassFile.meta.v3binaries) {
        xmlDoc.keePassFile.meta.v3binaries = [[V3BinariesList alloc] initWithContext:[XmlProcessingContext standardV3Context]];
    }
    
    NSMutableArray<V3Binary*>* v3Binaries = xmlDoc.keePassFile.meta.v3binaries.binaries;
    [v3Binaries removeAllObjects];
    
    int i = 0;
    for (DatabaseAttachment* binary in database.attachments) {
        V3Binary* bin = [[V3Binary alloc] initWithContext:[XmlProcessingContext standardV3Context]];
        bin.compressed = binary.compressed;
        bin.data = binary.data;
        bin.id = i++;
        [v3Binaries addObject:bin];
    }
    
    // 4. We need to calculate the header hash unfortunately before we generate the xml blob, and set it in the Xml
    
    KeePassDatabaseMetadata *metadata = (KeePassDatabaseMetadata*)database.metadata;
    XmlTreeSerializer *xmlSerializer = [[XmlTreeSerializer alloc] initWithProtectedStreamId:metadata.innerRandomStreamId
                                                                                        key:nil // Auto generated new key
                                                                                prettyPrint:NO];
    
    SerializationData *serializationData = [[SerializationData alloc] init];
    
    serializationData.protectedStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = adaptorTag ? adaptorTag.unknownHeaders : @{};
    serializationData.compressionFlags = metadata.compressionFlags;
    serializationData.innerRandomStreamId = metadata.innerRandomStreamId;
    serializationData.transformRounds = metadata.transformRounds;
    serializationData.fileVersion = metadata.version;
    serializationData.cipherId = metadata.cipherUuid;
    
    KdbxSerialization *kdbxSerializer = [[KdbxSerialization alloc] init:serializationData];
    
    // Set Header Hash
    
    NSString *headerHash = [kdbxSerializer stage1Serialize:database.masterPassword keyFileDigest:database.keyFileDigest error:error];
    if(!headerHash) {
        NSLog(@"Could not serialize Document to KDBX. Stage 1");
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX. Stage 1." errorCode:-6];
        }
        
        return nil;
    }
    
    [xmlDoc.keePassFile.meta setHash:headerHash];
    
    // 3. From Xml Model to Xml String (including inner stream encryption)
   
    XmlTree* xmlTree = [xmlDoc generateXmlTree];
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

static NSArray<DatabaseAttachment*>* getAttachments(RootXmlDomainObject *xmlDoc) {
    NSArray<V3Binary*>* v3Binaries = safeGetBinaries(xmlDoc);
    
    NSMutableArray<DatabaseAttachment*> *attachments = [NSMutableArray array];
    
    NSArray *sortedById = [v3Binaries sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [@(((V3Binary*)obj1).id) compare:@(((V3Binary*)obj2).id)];
    }];
    
    for (V3Binary* binary in sortedById) {
        DatabaseAttachment* dbA = [[DatabaseAttachment alloc] init];
        dbA.data = binary.data;
        dbA.compressed = binary.compressed;
        [attachments addObject:dbA];
    }
    
    return attachments;
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

@end
