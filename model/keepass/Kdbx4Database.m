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

static const uint32_t kKdbx4MajorVersionNumber = 4;
static const uint32_t kKdbx4MinorVersionNumber = 0;

static const BOOL kLogVerbose = NO;

@interface Kdbx4Database ()

@property (nonatomic) RootXmlDomainObject* existingRootXmlDocument;
@property (nonatomic) NSDictionary<NSNumber *,NSObject *>* existingExtraUnknownHeaders;

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

+ (BOOL)isAValidSafe:(NSData * _Nonnull)candidate {
    return keePass2SignatureAndVersionMatch(candidate, kKdbx4MajorVersionNumber, kKdbx4MinorVersionNumber);
}

- (instancetype)initNewWithoutPassword {
    return [self initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if (self = [super init]) {
        _rootGroup = [[Node alloc] initAsRoot:nil];
        
        Node* keePassRootGroup = [[Node alloc] initAsGroup:kDefaultRootGroupName parent:_rootGroup uuid:nil];
        [_rootGroup addChild:keePassRootGroup];
        
        _attachments = [NSMutableArray array];
        _customIcons = [NSMutableDictionary dictionary];
        _metadata = [[KeePass4DatabaseMetadata alloc] init];
        
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
        
        Kdbx4SerializationData *serializationData = [Kdbx4Serialization deserialize:safeData password:password ppError:ppError];
        
        if(serializationData == nil) {
            NSLog(@"Error getting Decrypting KDBX4 binary: [%@]", *ppError);
            return nil;
        }
        
        // NSLog(@"XML: \n\n%@\n\n", serializationData.xml);
        
        // 2. Convert the Xml to a more usable Xml Model

        self.existingRootXmlDocument = parseKeePassXml(serializationData.innerRandomStreamId,
                                                       serializationData.innerRandomStreamKey,
                                                       XmlProcessingContext.standardV4Context,
                                                       serializationData.xml,
                                                       ppError);
        
        if(self.existingRootXmlDocument == nil) {
            NSLog(@"Error in parseKeePassXml: [%@]", *ppError);
            return nil;
        }

        // 3. Convert the Xml Model to the Strongbox Model
        
        XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
        KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(self.existingRootXmlDocument);
        _rootGroup = [adaptor toModel:rootXmlGroup error:ppError];
        
        if(_rootGroup == nil) {
            NSLog(@"Error converting Xml model to Strongbox model: [%@]", *ppError);
            return nil;
        }

        // 4. Attachments

        _attachments = [serializationData.attachments mutableCopy];

        if(kLogVerbose) {
            NSLog(@"Attachments: %@", self.attachments);
        }
        
        // 5.
        
        _customIcons = safeGetCustomIcons(self.existingRootXmlDocument);
        
        // 6. Metadata
        
        _metadata = [[KeePass4DatabaseMetadata alloc] init];
        
        if(self.existingRootXmlDocument.keePassFile.meta.generator.text) {
            self.metadata.generator = self.existingRootXmlDocument.keePassFile.meta.generator.text;
        }
        
        self.metadata.cipherUuid = serializationData.cipherUuid;
        self.metadata.kdfParameters = serializationData.kdfParameters;
        self.metadata.innerRandomStreamId = serializationData.innerRandomStreamId;
        self.metadata.compressionFlags = serializationData.compressionFlags;
        self.metadata.version = serializationData.fileVersion;
        
        self.existingExtraUnknownHeaders = serializationData.extraUnknownHeaders;
        self.masterPassword = password;
    }
    
    return self;
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

- (NSData * _Nullable)getAsData:(NSError **)error {
    if(!self.masterPassword) {
        if(error) {
            *error = [Utils createNSError:@"Master Password not set." errorCode:-3];
        }
        
        return nil;
    }
    
    // 1. Attachments - Rationalise. This needs to come first in case we change the attachments list / and node references
    
    _attachments = [[AttachmentsRationalizer rationalizeAttachments:self.attachments root:self.rootGroup] mutableCopy];
    
    // 2. From Strongbox to Xml Model
    
    XmlStrongBoxModelAdaptor *xmlAdaptor = [[XmlStrongBoxModelAdaptor alloc] init];
    RootXmlDomainObject *rootXmlDocument = [xmlAdaptor toXmlModelFromStrongboxModel:self.rootGroup
                                                                        customIcons:self.customIcons
                                                            existingRootXmlDocument:self.existingRootXmlDocument
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
    
    XmlTreeSerializer *xmlSerializer = [[XmlTreeSerializer alloc] initWithProtectedStreamId:self.metadata.innerRandomStreamId
                                                                                        key:nil // Auto generated new key
                                                                                prettyPrint:NO];

    // 5. From Xml Model to Xml String (including inner stream encryption)
    
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

    Kdbx4SerializationData *serializationData = [[Kdbx4SerializationData alloc] init];
    
    serializationData.fileVersion = self.metadata.version;
    serializationData.compressionFlags = self.metadata.compressionFlags;
    serializationData.innerRandomStreamId = self.metadata.innerRandomStreamId;
    serializationData.innerRandomStreamKey = xmlSerializer.protectedStreamKey;
    serializationData.extraUnknownHeaders = self.existingExtraUnknownHeaders;
    serializationData.xml = xml;
    serializationData.kdfParameters = self.metadata.kdfParameters;
    serializationData.cipherUuid = self.metadata.cipherUuid;
    serializationData.attachments = self.attachments;
    
    NSData *data = [Kdbx4Serialization serialize:serializationData password:self.masterPassword ppError:error];
    if(!data) {
        NSLog(@"Could not serialize Document to KDBX.");

        if(error) {
            *error = [Utils createNSError:@"Could not serialize Document to KDBX." errorCode:-6];
        }

        return nil;
    }

    return data;
}

- (NSString * _Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return self.description;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"masterPassword = %@, metadata=%@, rootGroup = %@", self.masterPassword, self.metadata, self.rootGroup];
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    // Possible that one of these intermediates are nil... safety
    
    KeePassFile *keepassFileElement = existingRootXmlDocument == nil ? nil : existingRootXmlDocument.keePassFile;
    Root* rootXml = keepassFileElement == nil ? nil : keepassFileElement.root;
    KeePassGroup *rootXmlGroup = rootXml == nil ? nil : rootXml.rootGroup;
    
    return rootXmlGroup;
}

@end
