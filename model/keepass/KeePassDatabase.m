#import <Foundation/Foundation.h>
#import "KeePassDatabase.h"
#import "Utils.h"
#import "PwSafeSerialization.h"
#import "KdbxSerialization.h"
#import "RootXmlDomainObject.h"
#import "KeePassXmlModelAdaptor.h"
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

+ (DatabaseFormat)format {
    return kKeePass;
}

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return [KdbxSerialization isValidDatabase:prefix error:error];
}

+ (void)open:(NSData *)data ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [self read:stream ckf:ckf completion:completion];
}

+ (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    [self read:stream ckf:ckf xmlDumpStream:nil sanityCheckInnerStream:YES completion:completion];
}

+ (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf xmlDumpStream:(NSOutputStream*)xmlDumpStream sanityCheckInnerStream:(BOOL)sanityCheckInnerStream completion:(OpenCompletionBlock)completion {
    [KdbxSerialization deserialize:stream
               compositeKeyFactors:ckf
                     xmlDumpStream:xmlDumpStream
            sanityCheckInnerStream:sanityCheckInnerStream
                        completion:^(BOOL userCancelled, SerializationData * _Nullable serializationData, NSError * _Nullable error) {
        if(userCancelled || serializationData == nil || error) {
            if(error) {
                NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", error);
            }

            completion(userCancelled, nil, error);
            return;
        }
        
        onDeserialized(serializationData, ckf, completion);
    }];
}

static void onDeserialized(SerializationData *serializationData, CompositeKeyFactors *ckf, OpenCompletionBlock completion) {
    RootXmlDomainObject* xmlRoot = serializationData.rootXmlObject;
    Meta* meta = xmlRoot.keePassFile ? xmlRoot.keePassFile.meta : nil;
    
    
    
    BOOL ignoreHeaderHash = NO;
    if(!ignoreHeaderHash && meta && meta.headerHash) {
        if(![meta.headerHash isEqualToString:serializationData.headerHash]) {
            NSLog(@"Header Hash mismatch. Document has been corrupted or interfered with: [%@] != [%@]",
                  serializationData.headerHash,
                  meta.headerHash);
            
            NSError *error = [Utils createNSError:@"Header Hash incorrect. Document has been corrupted." errorCode:-3];
            completion(NO, nil, error);
            return;
        }
    }
 
    

    NSArray<DatabaseAttachment*>* attachments = [KeePassXmlModelAdaptor getV3Attachments:xmlRoot];
    NSDictionary<NSUUID*, NodeIcon*>* customIconPool = [KeePassXmlModelAdaptor getCustomIcons:meta];

    
        
    NSError* error;
    Node* rootGroup = [KeePassXmlModelAdaptor toStrongboxModel:xmlRoot attachments:attachments customIconPool:customIconPool error:&error];
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", error);
        completion(NO, nil, error);
        return;
    }
 
    
    
    NSDictionary<NSUUID*, NSDate*>* deletedObjects = [KeePassXmlModelAdaptor getDeletedObjects:xmlRoot];
    
    

    UnifiedDatabaseMetadata *metadata = [KeePassXmlModelAdaptor getMetadata:meta format:kKeePass];
    
    
    
    metadata.transformRounds = serializationData.transformRounds;
    metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
    metadata.compressionFlags = serializationData.compressionFlags;
    metadata.version = serializationData.fileVersion;
    metadata.cipherUuid = serializationData.cipherId;
    
    KeePass2TagPackage* adaptorTag = [[KeePass2TagPackage alloc] init];
    adaptorTag.unknownHeaders = serializationData.extraUnknownHeaders;
    adaptorTag.originalMeta = meta;
    
    DatabaseModel *ret = [[DatabaseModel alloc] initWithFormat:kKeePass compositeKeyFactors:ckf metadata:metadata root:rootGroup deletedObjects:deletedObjects iconPool:customIconPool];
    
    ret.meta.adaptorTag = adaptorTag;
    
    completion(NO, ret, nil);
}

+ (void)save:(DatabaseModel *)database completion:(SaveCompletionBlock)completion {
    if(!database.ckfs.password &&
       !database.ckfs.keyFileDigest &&
       !database.ckfs.yubiKeyCR) {
        NSError *error = [Utils createNSError:@"A least one composite key factor is required to encrypt database." errorCode:-3];
        completion(NO, nil, nil, error);
        return;
    }
    
    KeePass2TagPackage* adaptorTag = (KeePass2TagPackage*)database.meta.adaptorTag;
    
    
    
    KeePassXmlModelAdaptor *xmlAdaptor = [[KeePassXmlModelAdaptor alloc] init];
    NSError* err;
    
    KeePassDatabaseWideProperties* databaseProperties = [[KeePassDatabaseWideProperties alloc] init];
    databaseProperties.originalMeta = adaptorTag ? adaptorTag.originalMeta : nil;
    databaseProperties.deletedObjects = database.deletedObjects;
    databaseProperties.metadata = database.meta;
    
    NSArray<DatabaseAttachment*>* minimalAttachmentPool = @[];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toKeePassModel:database.rootNode
                                                   databaseProperties:databaseProperties
                                                              context:[XmlProcessingContext standardV3Context]
                                                minimalAttachmentPool:&minimalAttachmentPool
                                                             iconPool:database.iconPool
                                                                error:&err];
        
    if(!rootXmlDocument) {
        NSLog(@"Could not convert Database to Xml Model.");
        NSError *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        completion(NO, nil, nil, error);
        return;
    }

    
    
    
    if(!rootXmlDocument.keePassFile.meta.v3binaries) {
        rootXmlDocument.keePassFile.meta.v3binaries = [[V3BinariesList alloc] initWithContext:[XmlProcessingContext standardV3Context]];
    }
    
    NSMutableArray<V3Binary*>* v3Binaries = rootXmlDocument.keePassFile.meta.v3binaries.binaries;
    [v3Binaries removeAllObjects];
    
    int i = 0;
    for (DatabaseAttachment* binary in minimalAttachmentPool) {
        V3Binary* bin = [[V3Binary alloc] initWithContext:[XmlProcessingContext standardV3Context] dbAttachment:binary];
        bin.id = i++;
        [v3Binaries addObject:bin];
    }
    
    
    
    XmlSerializer *xmlSerializer = [[XmlSerializer alloc] initWithProtectedStreamId:database.meta.innerRandomStreamId
                                                                                key:nil 
                                                                           v4Format:NO
                                                                        prettyPrint:NO];
    
    SerializationData *serializationData = [[SerializationData alloc] init];
    
    serializationData.protectedStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = adaptorTag ? adaptorTag.unknownHeaders : @{};
    serializationData.compressionFlags = database.meta.compressionFlags;
    serializationData.innerRandomStreamId = database.meta.innerRandomStreamId;
    serializationData.transformRounds = database.meta.transformRounds;
    serializationData.fileVersion = database.meta.version;
    serializationData.cipherId = database.meta.cipherUuid;
    
    KdbxSerialization *kdbxSerializer = [[KdbxSerialization alloc] init:serializationData];
    
    
    
    [kdbxSerializer stage1Serialize:database.ckfs
                         completion:^(BOOL userCancelled, NSString * _Nullable hash, NSError * _Nullable error) {
        if (userCancelled || !hash || error) {
            if (!userCancelled) {
                NSLog(@"Could not serialize Document to KDBX. Stage 1");
                error = [Utils createNSError:@"Could not serialize Document to KDBX. Stage 1." errorCode:-6]; 
            }
            completion(userCancelled, nil, nil, error);
        }
        else {
            rootXmlDocument.keePassFile.meta.headerHash = hash;
            [self continueSaveWithHeaderHash:rootXmlDocument
                                    metadata:database.meta
                               xmlSerializer:xmlSerializer
                              kdbxSerializer:kdbxSerializer
                                  completion:completion];
        }
    }];
}

+ (void)continueSaveWithHeaderHash:(RootXmlDomainObject*)xmlDoc
                          metadata:(UnifiedDatabaseMetadata*)metadata
                     xmlSerializer:(XmlSerializer*)xmlSerializer
                    kdbxSerializer:(KdbxSerialization*)kdbxSerializer
                        completion:(SaveCompletionBlock)completion {
    xmlDoc.keePassFile.meta.recycleBinEnabled = metadata.recycleBinEnabled;
    xmlDoc.keePassFile.meta.recycleBinGroup = metadata.recycleBinGroup;
    xmlDoc.keePassFile.meta.recycleBinChanged = metadata.recycleBinChanged;
    xmlDoc.keePassFile.meta.historyMaxItems = metadata.historyMaxItems;
    xmlDoc.keePassFile.meta.historyMaxSize = metadata.historyMaxSize;
    
    
   
    [xmlSerializer beginDocument];
    BOOL writeXmlOk = [xmlDoc writeXml:xmlSerializer];
    [xmlSerializer endDocument];
    NSString *xml = xmlSerializer.xml;
    if(!xml || !writeXmlOk) {
        NSLog(@"Could not serialize Xml to Document.");
        NSError *error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        completion(NO, nil, nil, error);
        return;
    }
    
    
    
    NSError* err3;
    NSData *data = [kdbxSerializer stage2Serialize:xml error:&err3];
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");
        completion(NO, nil, nil, err3);
        return;
    }
    
    completion(NO, data, xml, nil);
}

@end
