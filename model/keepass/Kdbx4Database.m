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
static const uint32_t kKdbx4MaximumAcceptableMinorVersionNumber = 1; 

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

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return keePass2SignatureAndVersionMatch(prefix, kKdbx4MajorVersionNumber, kKdbx4MaximumAcceptableMinorVersionNumber, error);
}

- (StrongboxDatabase *)create:(CompositeKeyFactors *)ckf {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
    if ([rootGroupName isEqualToString:@"generic_database"]) { 
      rootGroupName = kDefaultRootGroupName;
    }
    Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];
    
    UnifiedDatabaseMetadata *metadata = [UnifiedDatabaseMetadata withDefaultsForFormat:kKeePass4];
    
    return [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata compositeKeyFactors:ckf];
}

- (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    [self read:stream ckf:ckf xmlDumpStream:nil sanityCheckInnerStream:YES completion:completion];
}

- (void)read:(NSInputStream *)stream
         ckf:(CompositeKeyFactors *)ckf
xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
  completion:(OpenCompletionBlock)completion {
    [Kdbx4Serialization deserialize:stream
                compositeKeyFactors:ckf
                      xmlDumpStream:xmlDumpStream
             sanityCheckInnerStream:sanityCheckInnerStream
                         completion:^(BOOL userCancelled, Kdbx4SerializationData * _Nullable serializationData, NSError * _Nullable error) {
        if(userCancelled || serializationData == nil || serializationData.rootXmlObject == nil || error) {
            if(error) {
                NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", error);
            }
            completion(userCancelled, nil, error);
            return;
        }

        onDeserialized(serializationData, ckf, completion);
    }];
}

static void onDeserialized(Kdbx4SerializationData * _Nullable serializationData, CompositeKeyFactors* ckf, OpenCompletionBlock completion) {
    
    
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
   
    
    
    UnifiedDatabaseMetadata *metadata = [UnifiedDatabaseMetadata withDefaultsForFormat:kKeePass4];
                                         
    if(xmlMeta) {
        metadata.generator = xmlMeta.generator ? xmlMeta.generator : @"<Unknown>";
        
        
        
        metadata.historyMaxItems = xmlMeta.historyMaxItems;
        metadata.historyMaxSize = xmlMeta.historyMaxSize;
    
        
        
        metadata.recycleBinEnabled = xmlMeta.recycleBinEnabled;
        metadata.recycleBinGroup = xmlMeta.recycleBinGroup;
        metadata.recycleBinChanged = xmlMeta.recycleBinChanged;
        
        

        metadata.customData = xmlMeta.customData.orderedDictionary;
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
}

- (void)save:(StrongboxDatabase *)database completion:(SaveCompletionBlock)completion {
    if(!database.compositeKeyFactors.password &&
       !database.compositeKeyFactors.keyFileDigest &&
       !database.compositeKeyFactors.yubiKeyCR) {
        NSError *error = [Utils createNSError:@"A least one composite key factor is required to encrypt database." errorCode:-3];
        completion(NO, nil, nil, error);
        return;
    }

    KeePass2TagPackage* tag = (KeePass2TagPackage*)database.adaptorTag;
    
    
    
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
        completion(NO, nil, nil, error);
        return;
    }
    
    
    
    rootXmlDocument.keePassFile.meta.headerHash = nil; 
    
    
    
    rootXmlDocument.keePassFile.meta.recycleBinEnabled = database.metadata.recycleBinEnabled;
    rootXmlDocument.keePassFile.meta.recycleBinGroup = database.metadata.recycleBinGroup;
    rootXmlDocument.keePassFile.meta.recycleBinChanged = database.metadata.recycleBinChanged;
    rootXmlDocument.keePassFile.meta.historyMaxItems = database.metadata.historyMaxItems;
    rootXmlDocument.keePassFile.meta.historyMaxSize = database.metadata.historyMaxSize;
    rootXmlDocument.keePassFile.meta.customData.orderedDictionary = database.metadata.customData;
    
    
    
    id<IXmlSerializer> xmlSerializer = [[XmlSerializer alloc] initWithProtectedStreamId:database.metadata.innerRandomStreamId
                                                                                    key:nil 
                                                                               v4Format:YES
                                                                            prettyPrint:NO];
    
    [xmlSerializer beginDocument];
    BOOL writeXmlOk = [rootXmlDocument writeXml:xmlSerializer];
    [xmlSerializer endDocument];
    NSString *xml = xmlSerializer.xml;
    if(!xml || !writeXmlOk) {
        NSLog(@"Could not serialize Xml to Document.:\n%@", xml);
        error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        completion(NO, nil, nil, error);
        return;
    }
    
    if(kLogVerbose) {
        NSLog(@"Serializing XML Document:\n%@", xml);
    }
    
    

    NSDictionary* unknownHeaders = tag ? tag.unknownHeaders : @{ };
    
    Kdbx4SerializationData *serializationData = [[Kdbx4SerializationData alloc] init];
    
    serializationData.fileVersion = database.metadata.version;
    serializationData.compressionFlags = database.metadata.compressionFlags;
    serializationData.innerRandomStreamId = database.metadata.innerRandomStreamId;
    serializationData.innerRandomStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = unknownHeaders;
    serializationData.kdfParameters = database.metadata.kdfParameters;
    serializationData.cipherUuid = database.metadata.cipherUuid;
    serializationData.attachments = database.attachments;
    
    [Kdbx4Serialization serialize:serializationData
                              xml:xml
                              ckf:database.compositeKeyFactors
                       completion:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        if (userCancelled) {
            completion(userCancelled, nil, nil, nil);
        }
        else if (!data || error) {
            NSLog(@"Could not serialize Document to KDBX.");
            completion(NO, nil, nil, error);
        }
        else {
            completion(NO, data, xml, nil);
        }
    }];
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    
    
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
                if(icon.data != nil) { 
                    [ret setObject:icon.data forKey:icon.uuid];
                }
            }
            return ret;
        }
    }
    
    return [NSMutableDictionary dictionary];
}

@end
