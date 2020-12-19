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
#import "KeePassXmlModelAdaptor.h"
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
    RootXmlDomainObject* xmlRoot = serializationData.rootXmlObject;
    Meta* meta = xmlRoot.keePassFile ? xmlRoot.keePassFile.meta : nil;
    
    
    
    NSError* error;
    Node* rootGroup = [KeePassXmlModelAdaptor getNodeModel:xmlRoot error:&error];
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", error);
        completion(NO, nil, error);
        return;
    }
    
    
    
    NSMutableDictionary<NSUUID*, NSData*>* customIcons = [KeePassXmlModelAdaptor getCustomIcons:meta];

    
    
    NSDictionary<NSUUID*, NSDate*>* deletedObjects = [KeePassXmlModelAdaptor getDeletedObjects:xmlRoot];
    
    
    
    UnifiedDatabaseMetadata *metadata = [KeePassXmlModelAdaptor getMetadata:meta format:kKeePass];
    
    
    
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
    tag.originalMeta = meta;
    
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
    
    
    
    KeePassXmlModelAdaptor *xmlAdaptor = [[KeePassXmlModelAdaptor alloc] init];
    
    KeePassDatabaseWideProperties* databaseProperties = [[KeePassDatabaseWideProperties alloc] init];
    databaseProperties.customIcons = database.customIcons;
    databaseProperties.originalMeta = tag ? tag.originalMeta : nil;
    databaseProperties.deletedObjects = database.deletedObjects;
    databaseProperties.metadata = database.metadata;
    
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

@end
