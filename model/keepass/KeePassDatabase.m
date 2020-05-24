#import <Foundation/Foundation.h>
#import "KeePassDatabase.h"
#import "Utils.h"
#import "PwSafeSerialization.h"
#import "KdbxSerialization.h"
#import "RootXmlDomainObject.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePassConstants.h"
#import "XmlSerializer.h"
#import "KdbxSerializationCommon.h"
#import "KeePass2TagPackage.h"
#import "NSArray+Extensions.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

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

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error {
    return [KdbxSerialization isAValidSafe:candidate error:error];
}

- (StrongboxDatabase *)create:(CompositeKeyFactors *)ckf {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    // Keepass has it's own root group to work off of, and doesn't allow entries at the actual root.
    // In the UI we don't display the actual root but the Keepass Root - We do display the name though
    
    NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
    if ([rootGroupName isEqualToString:@"generic_database"]) { // If it's not translated use default...
        rootGroupName = kDefaultRootGroupName;
    }
    Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    KeePassDatabaseMetadata* metadata = [[KeePassDatabaseMetadata alloc] init];
    
    StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata compositeKeyFactors:ckf];
    
    return ret;
}

- (void)open:(NSData *)data ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    [KdbxSerialization deserialize:data
               compositeKeyFactors:ckf
                        completion:^(BOOL userCancelled, SerializationData * _Nullable serializationData, NSError * _Nullable error) {
        if(userCancelled || serializationData == nil || error) {
            completion(userCancelled, nil, error);
            return;
        }
                
        RootXmlDomainObject* xmlObject = serializationData.rootXmlObject;
        Meta* xmlMeta = xmlObject.keePassFile ? xmlObject.keePassFile.meta : nil;
        
        // Verify Header Hash if present
        
        BOOL ignoreHeaderHash = NO;
        if(!ignoreHeaderHash && xmlMeta && xmlMeta.headerHash) {
            if(![xmlMeta.headerHash isEqualToString:serializationData.headerHash]) {
                NSLog(@"Header Hash mismatch. Document has been corrupted or interfered with: [%@] != [%@]",
                      serializationData.headerHash,
                      xmlMeta.headerHash);
                
                NSError *error = [Utils createNSError:@"Header Hash incorrect. Document has been corrupted." errorCode:-3];
                completion(NO, nil, error);
                return;
            }
        }
        
        // 4. Convert the Xml Model to the Strongbox Model
        
        XmlStrongBoxModelAdaptor *xmlStrongboxModelAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
        NSError* error2;
        Node* rootGroup = [xmlStrongboxModelAdaptor fromXmlModelToStrongboxModel:xmlObject error:&error2];
        if(rootGroup == nil) {
            NSLog(@"Error converting Xml model to Strongbox model: [%@]", error2);
            completion(NO, nil, error2);
            return;
        }

        // 5. Get Attachments
        
        NSArray<DatabaseAttachment*>* attachments = getAttachments(xmlObject);
        
        // 6.
        
        NSMutableDictionary<NSUUID*, NSData*>* customIcons = safeGetCustomIcons(xmlMeta);
        NSDictionary<NSUUID*, NSDate*>* deletedObjects = safeGetDeletedObjects(serializationData.rootXmlObject);
        
        // 7. Metadata

        KeePassDatabaseMetadata *metadata = [[KeePassDatabaseMetadata alloc] init];
        
        // 7.1 Generator

        if(xmlMeta) {
            metadata.generator = xmlMeta.generator ? xmlMeta.generator :  @"<Unknown>";
            
            // 7.2 History
            
            metadata.historyMaxItems = xmlMeta.historyMaxItems;
            metadata.historyMaxSize = xmlMeta.historyMaxSize;

            // 7.3 Recycle Bin
            
            metadata.recycleBinEnabled = xmlMeta.recycleBinEnabled;
            metadata.recycleBinGroup = xmlMeta.recycleBinGroup;
            metadata.recycleBinChanged = xmlMeta.recycleBinChanged;
        }
        
        // 7.4 Crypto...
        
        metadata.transformRounds = serializationData.transformRounds;
        metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
        metadata.compressionFlags = serializationData.compressionFlags;
        metadata.version = serializationData.fileVersion;
        metadata.cipherUuid = serializationData.cipherId;
        
        KeePass2TagPackage* adaptorTag = [[KeePass2TagPackage alloc] init];
        adaptorTag.unknownHeaders = serializationData.extraUnknownHeaders;
        adaptorTag.originalMeta = xmlMeta;
        
        StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                     metadata:metadata
                                                          compositeKeyFactors:ckf
                                                                  attachments:attachments
                                                                  customIcons:customIcons
                                                               deletedObjects:deletedObjects];
        ret.adaptorTag = adaptorTag;
        
        completion(NO, ret, nil);
    }];
}

- (void)save:(StrongboxDatabase *)database completion:(SaveCompletionBlock)completion {
    if(!database.compositeKeyFactors.password &&
       !database.compositeKeyFactors.keyFileDigest &&
       !database.compositeKeyFactors.yubiKeyCR) {
        NSError *error = [Utils createNSError:@"A least one composite key factor is required to encrypt database." errorCode:-3];
        completion(NO, nil, error);
        return;
    }
    
    KeePass2TagPackage* adaptorTag = (KeePass2TagPackage*)database.adaptorTag;
    
    // 1. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    NSError* err;
    
    KeePassDatabaseWideProperties* databaseProperties = [[KeePassDatabaseWideProperties alloc] init];
    databaseProperties.customIcons = database.customIcons;
    databaseProperties.originalMeta = adaptorTag ? adaptorTag.originalMeta : nil;
    databaseProperties.deletedObjects = database.deletedObjects;
    
    RootXmlDomainObject *xmlDoc = [xmlAdaptor toXmlModelFromStrongboxModel:database.rootGroup
                                                        databaseProperties:databaseProperties
                                                                   context:[XmlProcessingContext standardV3Context]
                                                                     error:&err];
    
    if(!xmlDoc) {
        NSLog(@"Could not convert Database to Xml Model.");
        NSError *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        completion(NO, nil, error);
        return;
    }
    
    // Add Attachments to Xml Doc
    
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
    XmlSerializer *xmlSerializer = [[XmlSerializer alloc] initWithProtectedStreamId:metadata.innerRandomStreamId
                                                                                key:nil // Auto generated new key
                                                                           v4Format:NO
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
    
    [kdbxSerializer stage1Serialize:database.compositeKeyFactors
                         completion:^(BOOL userCancelled, NSString * _Nullable hash, NSError * _Nullable error) {
        if (userCancelled || !hash || error) {
            if (!userCancelled) {
                NSLog(@"Could not serialize Document to KDBX. Stage 1");
                error = [Utils createNSError:@"Could not serialize Document to KDBX. Stage 1." errorCode:-6]; // Why Overwrite error?
            }
            completion(userCancelled, nil, error);
        }
        else {
            xmlDoc.keePassFile.meta.headerHash = hash;
            [self continueSaveWithHeaderHash:xmlDoc
                                    metadata:metadata
                               xmlSerializer:xmlSerializer
                              kdbxSerializer:kdbxSerializer
                                  completion:completion];
        }
    }];
}

- (void)continueSaveWithHeaderHash:(RootXmlDomainObject*)xmlDoc
                          metadata:(KeePassDatabaseMetadata*)metadata
                     xmlSerializer:(XmlSerializer*)xmlSerializer
                    kdbxSerializer:(KdbxSerialization*)kdbxSerializer
                        completion:(SaveCompletionBlock)completion {
    xmlDoc.keePassFile.meta.recycleBinEnabled = metadata.recycleBinEnabled;
    xmlDoc.keePassFile.meta.recycleBinGroup = metadata.recycleBinGroup;
    xmlDoc.keePassFile.meta.recycleBinChanged = metadata.recycleBinChanged;
    xmlDoc.keePassFile.meta.historyMaxItems = metadata.historyMaxItems;
    xmlDoc.keePassFile.meta.historyMaxSize = metadata.historyMaxSize;
    
    // From Xml Model to Xml String (including inner stream encryption)
   
    [xmlSerializer beginDocument];
    BOOL writeXmlOk = [xmlDoc writeXml:xmlSerializer];
    [xmlSerializer endDocument];
    NSString *xml = xmlSerializer.xml;
    if(!xml || !writeXmlOk) {
        NSLog(@"Could not serialize Xml to Document.");
        NSError *error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        completion(NO, nil, error);
        return;
    }
    
    // KDBX serialize this Xml Document...
    
    NSError* err3;
    NSData *data = [kdbxSerializer stage2Serialize:xml error:&err3];
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");
        completion(NO, nil, err3);
        return;
    }
    
    completion(NO, data, nil);
}

// TODO: Shouldn't these be in the XML Adaptor and in common wth KDBX4 etc

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

static NSMutableDictionary<NSUUID*, NSData*>* safeGetCustomIcons(Meta* meta) {
    if(meta.customIconList) {
        if(meta.customIconList.icons) {
            NSArray<CustomIcon*> *icons = meta.customIconList.icons;
            NSMutableDictionary<NSUUID*, NSData*> *ret = [NSMutableDictionary dictionaryWithCapacity:icons.count];
            for (CustomIcon* icon in icons) {
                if(icon.data != nil) { // Android KeePass DX seems some how to include no data sometimes? Causes crash
                    [ret setObject:icon.data forKey:icon.uuid];
                }
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

static NSDictionary<NSUUID*, NSDate*>* safeGetDeletedObjects(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    if (existingRootXmlDocument) {
        if (existingRootXmlDocument.keePassFile) {
            if (existingRootXmlDocument.keePassFile.root) {
                if (existingRootXmlDocument.keePassFile.root.deletedObjects) {
                    NSDictionary<NSUUID*, NSArray<DeletedObject*>*>* byUuid = [existingRootXmlDocument.keePassFile.root.deletedObjects.deletedObjects groupBy:^id _Nonnull(DeletedObject * _Nonnull obj) {
                        return obj.uuid;
                    }];
                    
                    NSMutableDictionary<NSUUID*, NSDate*> *ret = NSMutableDictionary.dictionary;
                    for (NSUUID* uuid in byUuid.allKeys) {
                        NSArray<DeletedObject*>* deletes = byUuid[uuid];
                        NSArray<DeletedObject*>* sortedDeletes = [deletes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                            DeletedObject* d1 = (DeletedObject*)obj1;
                            DeletedObject* d2 = (DeletedObject*)obj2;
                            return [d2.deletionTime compare:d1.deletionTime]; // Latest first
                        }];
                        
                        ret[uuid] = sortedDeletes.firstObject.deletionTime;
                    }
                    
                    return ret;
                }
            }
        }
    }
    
    return @{};
}

@end
