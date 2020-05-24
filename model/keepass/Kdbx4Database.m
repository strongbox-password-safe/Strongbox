//
//  Kdbx4Database.m
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdbx4Database.h"
#import "RootXmlDomainObject.h"
#import "KeePassConstants.h"
#import "Utils.h"
#import "KdbxSerializationCommon.h"
#import "Kdbx4Serialization.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "AttachmentsRationalizer.h"
#import "XmlSerializer.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePass2TagPackage.h"
#import "NSArray+Extensions.h"

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MaximumAcceptableMinorVersionNumber = 1; // MMcG - 10-Apr-2020 - KeeWeb had originally set a few of its files to 4.1 - now fixed but some users will have 4.1 in header - accept them

static const BOOL kLogVerbose = NO;

@implementation Kdbx4Database

+ (NSString *)fileExtension {
    return @"kdbx";
}

- (NSString *)fileExtension {
    return [Kdbx4Database fileExtension];
}

- (DatabaseFormat)format {
    return kKeePass4;
}

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error {
    return keePass2SignatureAndVersionMatch(candidate, kKdbx4MajorVersionNumber, kKdbx4MaximumAcceptableMinorVersionNumber, error);
}

- (StrongboxDatabase *)create:(CompositeKeyFactors *)ckf {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
    if ([rootGroupName isEqualToString:@"generic_database"]) { // If it's not translated use default...
      rootGroupName = kDefaultRootGroupName;
    }
    Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    KeePass4DatabaseMetadata *metadata = [[KeePass4DatabaseMetadata alloc] init];
    
    return [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata compositeKeyFactors:ckf];
}

- (void)open:(NSData *)data ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    [Kdbx4Serialization deserialize:data
                compositeKeyFactors:ckf
                         completion:^(BOOL userCancelled, Kdbx4SerializationData* serializationData, NSError* error) {
    if(userCancelled || serializationData == nil || serializationData.rootXmlObject == nil || error) {
        if(error) {
            NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", error);
        }
        completion(userCancelled, nil, error);
        return;
    }
            
    // Convert the Xml Model to the Strongbox Model
    
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(serializationData.rootXmlObject);
    
    NSError* err;
    Node* rootGroup = [adaptor toModel:rootXmlGroup error:&err];
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", err);
        completion(NO, nil, err);
        return;
    }
    
    Meta* xmlMeta = serializationData.rootXmlObject.keePassFile ? serializationData.rootXmlObject.keePassFile.meta : nil;
    NSMutableDictionary<NSUUID*, NSData*>* customIcons = safeGetCustomIcons(xmlMeta);
    NSDictionary<NSUUID*, NSDate*>* deletedObjects = safeGetDeletedObjects(serializationData.rootXmlObject);
        
    // Metadata
    
    KeePass4DatabaseMetadata *metadata = [[KeePass4DatabaseMetadata alloc] init];
    
    if(xmlMeta) {
        metadata.generator = xmlMeta.generator ? xmlMeta.generator : @"<Unknown>";
        
        // History Settings
        
        metadata.historyMaxItems = xmlMeta.historyMaxItems;
        metadata.historyMaxSize = xmlMeta.historyMaxSize;
    
        // Recycle Bin Settings
        
        metadata.recycleBinEnabled = xmlMeta.recycleBinEnabled;
        metadata.recycleBinGroup = xmlMeta.recycleBinGroup;
        metadata.recycleBinChanged = xmlMeta.recycleBinChanged;
    }
    
    metadata.cipherUuid = serializationData.cipherUuid;
    metadata.kdfParameters = serializationData.kdfParameters;
    metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
    metadata.compressionFlags = serializationData.compressionFlags;
    metadata.version = serializationData.fileVersion;
    
    StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                      compositeKeyFactors:ckf
                                                              attachments:serializationData.attachments
                                                              customIcons:customIcons
                                                           deletedObjects:deletedObjects];

    KeePass2TagPackage* tag = [[KeePass2TagPackage alloc] init];
    tag.unknownHeaders = serializationData.extraUnknownHeaders;
    tag.originalMeta = xmlMeta;
    
    ret.adaptorTag = tag;
    
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

    KeePass2TagPackage* tag = (KeePass2TagPackage*)database.adaptorTag;
    
    // From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    
    KeePassDatabaseWideProperties* databaseProperties = [[KeePassDatabaseWideProperties alloc] init];
    databaseProperties.customIcons = database.customIcons;
    databaseProperties.originalMeta = tag ? tag.originalMeta : nil;
    databaseProperties.deletedObjects = database.deletedObjects;
    
    NSError* error;
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:database.rootGroup
                                                                 databaseProperties:databaseProperties
                                                                            context:[XmlProcessingContext standardV4Context]
                                                                              error:&error];
    
    if(!rootXmlDocument) {
        NSLog(@"Could not convert Database to Xml Model.");
        error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        completion(NO, nil, error);
        return;
    }
    
    // Metadata
    
    rootXmlDocument.keePassFile.meta.headerHash = nil; // Do not serialize this, we do not calculate it
    KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)database.metadata;
    
    // Write Back any changed Metadata
    
    rootXmlDocument.keePassFile.meta.recycleBinEnabled = metadata.recycleBinEnabled;
    rootXmlDocument.keePassFile.meta.recycleBinGroup = metadata.recycleBinGroup;
    rootXmlDocument.keePassFile.meta.recycleBinChanged = metadata.recycleBinChanged;
    rootXmlDocument.keePassFile.meta.historyMaxItems = metadata.historyMaxItems;
    rootXmlDocument.keePassFile.meta.historyMaxSize = metadata.historyMaxSize;
    
    // From Xml Model to Xml String (including inner stream encryption)
    
    id<IXmlSerializer> xmlSerializer = [[XmlSerializer alloc] initWithProtectedStreamId:metadata.innerRandomStreamId
                                                                                    key:nil // Auto generated new key
                                                                               v4Format:YES
                                                                            prettyPrint:NO];
    
    [xmlSerializer beginDocument];
    BOOL writeXmlOk = [rootXmlDocument writeXml:xmlSerializer];
    [xmlSerializer endDocument];
    NSString *xml = xmlSerializer.xml;
    if(!xml || !writeXmlOk) {
        NSLog(@"Could not serialize Xml to Document.:\n%@", xml);
        error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        completion(NO, nil, error);
        return;
    }
    
    if(kLogVerbose) {
        NSLog(@"Serializing XML Document:\n%@", xml);
    }
    
    // KDBX serialize this Xml Document...

    NSDictionary* unknownHeaders = tag ? tag.unknownHeaders : @{ };
    
    Kdbx4SerializationData *serializationData = [[Kdbx4SerializationData alloc] init];
    
    serializationData.fileVersion = metadata.version;
    serializationData.compressionFlags = metadata.compressionFlags;
    serializationData.innerRandomStreamId = metadata.innerRandomStreamId;
    serializationData.innerRandomStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = unknownHeaders;
    serializationData.kdfParameters = metadata.kdfParameters;
    serializationData.cipherUuid = metadata.cipherUuid;
    serializationData.attachments = database.attachments;
    
    [Kdbx4Serialization serialize:serializationData
                              xml:xml
                              ckf:database.compositeKeyFactors
                       completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled) {
            completion(userCancelled, nil, nil);
        }
        else if (!data || error) {
            NSLog(@"Could not serialize Document to KDBX.");
            completion(NO, nil, error);
        }
        else {
            completion(NO, data, nil);
        }
    }];
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    // Possible that one of these intermediates are nil... safety
    
    KeePassFile *keepassFileElement = existingRootXmlDocument == nil ? nil : existingRootXmlDocument.keePassFile;
    Root* rootXml = keepassFileElement == nil ? nil : keepassFileElement.root;
    KeePassGroup *rootXmlGroup = rootXml == nil ? nil : rootXml.rootGroup;
    
    return rootXmlGroup;
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

// TODO: Duplicated in KDBX3
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
