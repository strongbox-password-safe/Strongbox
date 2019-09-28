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

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MinorVersionNumber = 0;

static const BOOL kLogVerbose = NO;

@implementation Kdbx4Database

+ (NSData *)getYubikeyChallenge:(NSData *)candidate error:(NSError **)error {
    return [Kdbx4Serialization getYubikeyChallenge:candidate error:error];
}

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
    return keePass2SignatureAndVersionMatch(candidate, kKdbx4MajorVersionNumber, kKdbx4MinorVersionNumber, error);
}

- (StrongboxDatabase *)create:(CompositeKeyFactors *)compositeKeyFactors {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:rootGroup allowDuplicateGroupTitles:YES uuid:nil];
    [rootGroup addChild:keePassRootGroup allowDuplicateGroupTitles:YES];
    
    KeePass4DatabaseMetadata *metadata = [[KeePass4DatabaseMetadata alloc] init];
    
    return [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata compositeKeyFactors:compositeKeyFactors];
}

- (StrongboxDatabase *)open:(NSData *)data compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors error:(NSError **)error {
    Kdbx4SerializationData *serializationData = [Kdbx4Serialization deserialize:data compositeKey:compositeKeyFactors ppError:error];
    
    if(serializationData == nil) {
        NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", *error);
        return nil;
    }
    
    RootXmlDomainObject* xmlObject = serializationData.rootXmlObject;
    if(xmlObject == nil) {
        NSLog(@"Error in parseKeePassXml: [%@]", *error);
        return nil;
    }
    
    // 3. Convert the Xml Model to the Strongbox Model
    
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(xmlObject);
    Node* rootGroup = [adaptor toModel:rootXmlGroup error:error];
    
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", *error);
        return nil;
    }
    
    Meta* xmlMeta = xmlObject.keePassFile ? xmlObject.keePassFile.meta : nil;
    NSMutableDictionary<NSUUID*, NSData*>* customIcons = safeGetCustomIcons(xmlMeta);
    
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
                                                      compositeKeyFactors:compositeKeyFactors
                                                              attachments:serializationData.attachments
                                                              customIcons:customIcons];

    KeePass2TagPackage* tag = [[KeePass2TagPackage alloc] init];
    tag.unknownHeaders = serializationData.extraUnknownHeaders;
    tag.originalMeta = xmlMeta;
    
    ret.adaptorTag = tag;
    
    return ret;
}

- (NSData *)save:(StrongboxDatabase *)database error:(NSError **)error {
    if(!database.compositeKeyFactors.password && !database.compositeKeyFactors.keyFileDigest) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }

    KeePass2TagPackage* tag = (KeePass2TagPackage*)database.adaptorTag;
    Meta* originalMeta = tag ? tag.originalMeta : nil;
    
    // 1. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:database.rootGroup
                                                                        customIcons:database.customIcons
                                                                       originalMeta:originalMeta
                                                                            context:[XmlProcessingContext standardV4Context]
                                                                              error:error];
    
    if(!rootXmlDocument) {
        NSLog(@"Could not convert Database to Xml Model.");
        if(error) {
            *error = [Utils createNSError:@"Could not convert Database to Xml Model." errorCode:-4];
        }
        
        return nil;
    }
    
    // 3. Metadata
    
    rootXmlDocument.keePassFile.meta.headerHash = nil; // Do not serialize this, we do not calculate it
    
    KeePass4DatabaseMetadata* metadata = (KeePass4DatabaseMetadata*)database.metadata;
    
    // 4. Write Back any changed Metadata
    
    rootXmlDocument.keePassFile.meta.recycleBinEnabled = metadata.recycleBinEnabled;
    rootXmlDocument.keePassFile.meta.recycleBinGroup = metadata.recycleBinGroup;
    rootXmlDocument.keePassFile.meta.recycleBinChanged = metadata.recycleBinChanged;
    rootXmlDocument.keePassFile.meta.historyMaxItems = metadata.historyMaxItems;
    rootXmlDocument.keePassFile.meta.historyMaxSize = metadata.historyMaxSize;
    
    // 5. From Xml Model to Xml String (including inner stream encryption)
    
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
        
        if(error) {
            *error = [Utils createNSError:@"Could not serialize Xml to Document." errorCode:-5];
        }
        
        return nil;
    }
    
    if(kLogVerbose) {
        NSLog(@"Serializing XML Document:\n%@", xml);
    }
    
    // 3. KDBX serialize this Xml Document...

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
    
    NSData *data = [Kdbx4Serialization serialize:serializationData xml:xml compositeKey:database.compositeKeyFactors ppError:error];
    
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");

        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX." errorCode:-6];
        }

        return nil;
    }

    return data;
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
                [ret setObject:icon.data forKey:icon.uuid];
            }
            return ret;
        }
    }
    
    return [NSMutableDictionary dictionary];
}

@end
