//
//  Kdbx4Database.m
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Kdbx4Database.h"
#import "RootXmlDomainObject.h"
#import "KeePassConstants.h"
#import "Utils.h"
#import "KdbxSerializationCommon.h"
#import "Kdbx4Serialization.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "KeePassXmlModelAdaptor.h"
#import "KeePass2TagPackage.h"
#import "NSArray+Extensions.h"
#import "XmlSerializer.h"
#import "InnerRandomStreamFactory.h"
#import "NSData+Extensions.h"

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MaximumAcceptableMinorVersionNumber = 1; 

@implementation Kdbx4Database

+ (NSString *)fileExtension {
    return @"kdbx";
}

+ (DatabaseFormat)format {
    return kKeePass4;
}

+ (BOOL)isValidDatabase:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    return keePass2SignatureAndVersionMatch(prefix, kKdbx4MajorVersionNumber, kKdbx4MaximumAcceptableMinorVersionNumber, error);
}

+ (void)read:(NSInputStream *)stream ckf:(CompositeKeyFactors *)ckf completion:(OpenCompletionBlock)completion {
    [self read:stream ckf:ckf xmlDumpStream:nil sanityCheckInnerStream:YES completion:completion];
}

+ (void)read:(NSInputStream *)stream
         ckf:(CompositeKeyFactors *)ckf
xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
  completion:(OpenCompletionBlock)completion {
    [Kdbx4Serialization deserialize:stream
                compositeKeyFactors:ckf
                      xmlDumpStream:xmlDumpStream
             sanityCheckInnerStream:sanityCheckInnerStream
                         completion:^(BOOL userCancelled, Kdbx4SerializationData * _Nullable serializationData, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        if(userCancelled || serializationData == nil || serializationData.rootXmlObject == nil || error) {
            if(error) {
                slog(@"Error getting Decrypting KDBX4 binary: [%@]", error);
            }
            completion(userCancelled, nil, innerStreamError, error);
            return;
        }

        onDeserialized(serializationData, innerStreamError, ckf, completion);
    }];
}

static void onDeserialized(Kdbx4SerializationData * _Nullable serializationData, NSError * _Nullable innerStreamError, CompositeKeyFactors* ckf, OpenCompletionBlock completion) {
    RootXmlDomainObject* xmlRoot = serializationData.rootXmlObject;
    Meta* meta = xmlRoot.keePassFile ? xmlRoot.keePassFile.meta : nil;
        
    
    
    NSDictionary<NSUUID*, NodeIcon*>* customIcons = [KeePassXmlModelAdaptor getCustomIcons:meta];

    

    NSError* error;
    Node* rootGroup = [KeePassXmlModelAdaptor toStrongboxModel:xmlRoot attachments:serializationData.attachments customIconPool:customIcons error:&error];
    if(rootGroup == nil) {
        slog(@"Error converting Xml model to Strongbox model: [%@]", error);
        completion(NO, nil, innerStreamError, error);
        return;
    }
    

    
    
    NSDictionary<NSUUID*, NSDate*>* deletedObjects = [KeePassXmlModelAdaptor getDeletedObjects:xmlRoot];
    
    
    
    UnifiedDatabaseMetadata *metadata = [KeePassXmlModelAdaptor getMetadata:meta format:kKeePass];
    
    
    
    metadata.cipherUuid = serializationData.cipherUuid;
    metadata.kdfParameters = serializationData.kdfParameters;
    metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
    metadata.compressionFlags = serializationData.compressionFlags;
    metadata.version = serializationData.fileVersion;
    
    DatabaseModel* ret = [[DatabaseModel alloc] initWithFormat:kKeePass4
                                           compositeKeyFactors:ckf
                                                      metadata:metadata
                                                          root:rootGroup
                                                deletedObjects:deletedObjects
                                                      iconPool:customIcons];

    KeePass2TagPackage* tag = [[KeePass2TagPackage alloc] init];
    tag.unknownHeaders = serializationData.extraUnknownHeaders; 
    
    ret.meta.adaptorTag = tag;
    
    completion(NO, ret, innerStreamError, nil);
}

+ (void)save:(DatabaseModel *)database 
outputStream:(NSOutputStream *)outputStream
      params:(id)params
  completion:(SaveCompletionBlock)completion {
    if(!database.ckfs.password &&
       !database.ckfs.keyFileDigest &&
       !database.ckfs.yubiKeyCR) {
        NSError *error = [Utils createNSError:@"A least one composite key factor is required to encrypt database." errorCode:-3];
        completion(NO, nil, error);
        return;
    }

    KeePass2TagPackage* tag = (KeePass2TagPackage*)database.meta.adaptorTag;
    
    
    
    KeePassXmlModelAdaptor *xmlAdaptor = [[KeePassXmlModelAdaptor alloc] init];
    
    KeePassDatabaseWideProperties* databaseProperties = [[KeePassDatabaseWideProperties alloc] init];
    databaseProperties.deletedObjects = database.deletedObjects;
    databaseProperties.metadata = database.meta;
    
    NSError* error;
    
    NSArray<KeePassAttachmentAbstractionLayer*>* minimalAttachmentPool = @[];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toKeePassModel:database.rootNode
                                                   databaseProperties:databaseProperties
                                                              context:[XmlProcessingContext standardV4Context]
                                                minimalAttachmentPool:&minimalAttachmentPool
                                                             iconPool:database.iconPool
                                                                error:&error];
    
    if(!rootXmlDocument) {
        slog(@"Could not convert Database to Xml Model.");
        error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        completion(NO, nil, error);
        return;
    }
    
    
    
    rootXmlDocument.keePassFile.meta.headerHash = nil; 
        
    id<InnerRandomStream> innerStream = [InnerRandomStreamFactory getStream:database.meta.innerRandomStreamId key:nil];
            
    

    NSDictionary* unknownHeaders = tag ? tag.unknownHeaders : @{ };
    
    Kdbx4SerializationData *serializationData = [[Kdbx4SerializationData alloc] init];
    
    serializationData.fileVersion = database.meta.version;
    serializationData.compressionFlags = database.meta.compressionFlags;
    serializationData.innerRandomStreamId = database.meta.innerRandomStreamId;
    serializationData.innerRandomStreamKey = innerStream.key;
    serializationData.extraUnknownHeaders = unknownHeaders;
    serializationData.kdfParameters = database.meta.kdfParameters;
    serializationData.cipherUuid = database.meta.cipherUuid;
    serializationData.attachments = minimalAttachmentPool;
    
    [Kdbx4Serialization serialize:serializationData
                  rootXmlDocument:rootXmlDocument
                      innerStream:innerStream
                              ckf:database.ckfs
                     outputStream:outputStream
                       completion:^(BOOL userCancelled, NSError * _Nullable error) {
        if (userCancelled) {
            completion(userCancelled, nil, nil);
        }
        else if ( error ) {
            slog(@"Could not serialize Document to KDBX.");
            completion(NO, nil, error);
        }
        else {
            completion(NO, nil, nil);
        }
    }];
}

@end
