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
#import "KeePassXmlParserDelegate.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "AttachmentsRationalizer.h"
#import "XmlTreeSerializer.h"
#import "XmlStrongBoxModelAdaptor.h"
#import "KeePass2TagPackage.h"

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MinorVersionNumber = 0;

static const BOOL kLogVerbose = NO;

@interface Kdbx4Database ()

@end

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
    return keePass2SignatureAndVersionMatch(candidate, kKdbx4MajorVersionNumber, kKdbx4MinorVersionNumber, error);
}

- (StrongboxDatabase *)create:(NSString *)password {
    return [self create:password keyFileDigest:nil];
}

-(StrongboxDatabase *)create:(NSString *)password keyFileDigest:(NSData *)keyFileDigest {
    Node* rootGroup = [[Node alloc] initAsRoot:nil];
    
    Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:rootGroup uuid:nil];
    [rootGroup addChild:keePassRootGroup];
    
    KeePass4DatabaseMetadata *metadata = [[KeePass4DatabaseMetadata alloc] init];
    
    return [[StrongboxDatabase alloc] initWithRootGroup:rootGroup metadata:metadata masterPassword:password keyFileDigest:keyFileDigest];
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password error:(NSError **)error {
    return [self open:data password:password keyFileDigest:nil error:error];
}

- (StrongboxDatabase *)open:(NSData *)data password:(NSString *)password keyFileDigest:(NSData *)keyFileDigest error:(NSError **)error {
    // 1. First get XML out of the encrypted binary...
    
    Kdbx4SerializationData *serializationData = [Kdbx4Serialization deserialize:data password:password keyFileDigest:keyFileDigest ppError:error];
    
    if(serializationData == nil) {
        NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", *error);
        return nil;
    }
    
    // NSLog(@"XML: \n\n%@\n\n", serializationData.xml);
    
    // 2. Convert the Xml to a more usable Xml Model

    RootXmlDomainObject* xmlDoc = parseKeePassXml(serializationData.innerRandomStreamId,
                                                   serializationData.innerRandomStreamKey,
                                                   XmlProcessingContext.standardV4Context,
                                                   serializationData.xml,
                                                   error);
    
    if(xmlDoc == nil) {
        NSLog(@"Error in parseKeePassXml: [%@]", *error);
        return nil;
    }

    // 3. Convert the Xml Model to the Strongbox Model
    
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(xmlDoc);
    Node* rootGroup = [adaptor toModel:rootXmlGroup error:error];
    
    if(rootGroup == nil) {
        NSLog(@"Error converting Xml model to Strongbox model: [%@]", *error);
        return nil;
    }
    
    NSMutableDictionary<NSUUID*, NSData*>* customIcons = safeGetCustomIcons(xmlDoc);
    
    // Metadata
    
    KeePass4DatabaseMetadata *metadata = [[KeePass4DatabaseMetadata alloc] init];
    
    if(xmlDoc.keePassFile.meta.generator.text) {
        metadata.generator = xmlDoc.keePassFile.meta.generator.text;
    }
    
    // History Settings
    
    if(xmlDoc.keePassFile.meta.historyMaxItems) {
        metadata.historyMaxItems = xmlDoc.keePassFile.meta.historyMaxItems.integer;
    }
    if(xmlDoc.keePassFile.meta.historyMaxSize) {
        metadata.historyMaxSize = xmlDoc.keePassFile.meta.historyMaxSize.integer;
    }

    // Recycle Bin Settings
    
    if(xmlDoc.keePassFile.meta.recycleBinEnabled) {
        metadata.recycleBinEnabled = xmlDoc.keePassFile.meta.recycleBinEnabled.booleanValue;
    }
    if(xmlDoc.keePassFile.meta.recycleBinGroup) {
        metadata.recycleBinGroup = xmlDoc.keePassFile.meta.recycleBinGroup.uuid;
    }
    if(xmlDoc.keePassFile.meta.recycleBinChanged) {
        metadata.recycleBinChanged = xmlDoc.keePassFile.meta.recycleBinChanged.date;
    }

    metadata.cipherUuid = serializationData.cipherUuid;
    metadata.kdfParameters = serializationData.kdfParameters;
    metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
    metadata.compressionFlags = serializationData.compressionFlags;
    metadata.version = serializationData.fileVersion;
    
    StrongboxDatabase* ret = [[StrongboxDatabase alloc] initWithRootGroup:rootGroup
                                                                 metadata:metadata
                                                           masterPassword:password
                                                            keyFileDigest:keyFileDigest
                                                              attachments:serializationData.attachments
                                                              customIcons:customIcons];

    KeePass2TagPackage* tag = [[KeePass2TagPackage alloc] init];
    tag.unknownHeaders = serializationData.extraUnknownHeaders;
    tag.xmlDocument = xmlDoc;
    
    ret.adaptorTag = tag;
    
    return ret;
}

- (NSData *)save:(StrongboxDatabase *)database error:(NSError **)error {
    if(!database.masterPassword && !database.keyFileDigest) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }

    KeePass2TagPackage* tag = (KeePass2TagPackage*)database.adaptorTag;
    RootXmlDomainObject* existingRootXmlDocument = tag ? tag.xmlDocument : nil;
    
    // 1. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:database.rootGroup
                                                                        customIcons:database.customIcons
                                                            existingRootXmlDocument:existingRootXmlDocument
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
    
    rootXmlDocument.keePassFile.meta.recycleBinEnabled.booleanValue = metadata.recycleBinEnabled;
    rootXmlDocument.keePassFile.meta.recycleBinGroup.uuid = metadata.recycleBinGroup;
    rootXmlDocument.keePassFile.meta.recycleBinChanged.date = metadata.recycleBinChanged;
    
    // 5. From Xml Model to Xml String (including inner stream encryption)
    
    XmlTreeSerializer *xmlSerializer = [[XmlTreeSerializer alloc] initWithProtectedStreamId:metadata.innerRandomStreamId
                                                                                        key:nil // Auto generated new key
                                                                                prettyPrint:NO];

    XmlTree* xmlTree = [rootXmlDocument generateXmlTree];
    NSString *xml = [xmlSerializer serializeTrees:xmlTree.children];
    
    if(!xml) {
        NSLog(@"Could not serialize Xml to Document.");
        
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
    serializationData.xml = xml;
    serializationData.kdfParameters = metadata.kdfParameters;
    serializationData.cipherUuid = metadata.cipherUuid;
    serializationData.attachments = database.attachments;
    
    NSData *data = [Kdbx4Serialization serialize:serializationData password:database.masterPassword keyFileDigest:database.keyFileDigest ppError:error];
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

@end
