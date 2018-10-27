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

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MinorVersionNumber = 0;

@interface Kdbx4Database ()

@property (nonatomic) RootXmlDomainObject* existingRootXmlDocument;
@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* existingExtraUnknownHeaders;

@end

@implementation Kdbx4Database

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
        _rootGroup = [[Node alloc] initAsRoot:nil];
        
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
        
        SerializationData *serializationData = [Kdbx4Serialization deserialize:safeData password:password ppError:ppError];
        
        if(serializationData == nil) {
            NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", *ppError);
            return nil;
        }
        
//        // 2. Convert the Xml to a more usable Xml Model
//
//        NSLog(@"%@", serializationData.xml);
//
//        self.existingRootXmlDocument = [self parseKeePassXml:serializationData error:ppError];
//        if(self.existingRootXmlDocument == nil) {
//            NSLog(@"Error getting parseKeePassXml: [%@]", *ppError);
//            return nil;
//        }
//
//        // 3. Verify Header Hash if present
//
//        if(!ignoreHeaderHash && self.existingRootXmlDocument.keePassFile.meta.headerHash) {
//            if(![self.existingRootXmlDocument.keePassFile.meta.headerHash.text isEqualToString:serializationData.headerHash]) {
//                NSLog(@"Header Hash mismatch. Document has been corrupted or interfered with: [%@] != [%@]",
//                      serializationData.headerHash,
//                      self.existingRootXmlDocument.keePassFile.meta.headerHash.text);
//
//                if(ppError != nil) {
//                    *ppError = [Utils createNSError:@"Header Hash incorrect. Document has been corrupted." errorCode:-3];
//                }
//
//                return nil;
//            }
//        }
//
//        // 4. Convert the Xml Model to the Strongbox Model
//
//        XmlStrongBoxModelAdaptor *xmlStrongboxModelAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
//        KeepassMetaDataAndNodeModel *metadataAndNodeModel = [xmlStrongboxModelAdaptor fromXmlModelToStrongboxModel:self.existingRootXmlDocument error:ppError];
//
//        if(metadataAndNodeModel == nil) {
//            NSLog(@"Error converting Xml model to Strongbox model: [%@]", *ppError);
//            return nil;
//        }
//
//        _rootGroup = metadataAndNodeModel.rootNode;
//        _metadata = metadataAndNodeModel.metadata;
//
//        self.metadata.transformRounds = serializationData.transformRounds;
//        self.metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
//        self.metadata.compressionFlags = serializationData.compressionFlags;
//        self.metadata.version = serializationData.fileVersion;
        
        self.existingExtraUnknownHeaders = serializationData.extraUnknownHeaders;
        self.masterPassword = password;
    }
    
    return self;
}

+ (BOOL)isAValidSafe:(NSData * _Nonnull)candidate {
    return keePassSignatureAndVersionMatch(candidate, kKdbx4MajorVersionNumber, kKdbx4MinorVersionNumber);
}

- (NSData * _Nullable)getAsData:(NSError *__autoreleasing  _Nonnull * _Nonnull)error {
    return nil; // TODO:
}

- (NSString * _Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return self.description;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

@end
