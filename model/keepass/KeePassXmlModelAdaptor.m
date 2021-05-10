//
//  XmlStrongBoxModelAdaptor.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassXmlModelAdaptor.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "Utils.h"
#import "KeePassConstants.h"
#import "NSArray+Extensions.h"

@implementation KeePassXmlModelAdaptor

+ (Node *)toStrongboxModel:(RootXmlDomainObject *)xmlRoot error:(NSError *__autoreleasing  _Nullable *)error {
    return [KeePassXmlModelAdaptor toStrongboxModel:xmlRoot attachments:@[] customIconPool:@{} error:error];
}

+ (Node *)toStrongboxModel:(RootXmlDomainObject *)xmlRoot
               attachments:(NSArray<DatabaseAttachment *> *)attachments
            customIconPool:(NSDictionary<NSUUID *,NodeIcon *> *)customIconPool
                     error:(NSError *__autoreleasing  _Nullable *)error {
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    
    KeePassGroup * rootGroup = getExistingRootKeePassGroup(xmlRoot);
    
    Node* rootNode = [adaptor toStrongboxModel:rootGroup attachmentsPool:attachments customIconPool:customIconPool error:error];
    
    if(!rootNode) {
        NSLog(@"Could not build node model from xml root document.");
        
        if (error != nil) {
            *error = [Utils createNSError:@"Could not parse this database." errorCode:-1];
        }
        
        return nil;
    }
    
    return rootNode;
}

+ (UnifiedDatabaseMetadata*)getMetadata:(Meta*)meta format:(DatabaseFormat)format {
    UnifiedDatabaseMetadata *metadata = [UnifiedDatabaseMetadata withDefaultsForFormat:format];

    if(meta) {
        metadata.generator = meta.generator ? meta.generator :  @"<Unknown>";
        metadata.historyMaxItems = meta.historyMaxItems;
        metadata.historyMaxSize = meta.historyMaxSize;
        metadata.recycleBinEnabled = meta.recycleBinEnabled;
        metadata.recycleBinGroup = meta.recycleBinGroup;
        metadata.recycleBinChanged = meta.recycleBinChanged;
        metadata.customData = meta.customData ? meta.customData.dictionary : @{}.mutableCopy;
        metadata.settingsChanged = meta.settingsChanged;
        metadata.databaseName = meta.databaseName;
        metadata.databaseNameChanged = meta.databaseNameChanged;
        metadata.databaseDescription = meta.databaseDescription;
        metadata.databaseDescriptionChanged = meta.databaseDescriptionChanged;
        metadata.defaultUserName = meta.defaultUserName;
        metadata.defaultUserNameChanged = meta.defaultUserNameChanged;
        metadata.color = meta.color;
        metadata.entryTemplatesGroup = meta.entryTemplatesGroup;
        metadata.entryTemplatesGroupChanged = meta.entryTemplatesGroupChanged;
    }
    
    return metadata;
}

- (RootXmlDomainObject *)toKeePassModel:(Node *)rootNode
                     databaseProperties:(KeePassDatabaseWideProperties *)databaseProperties
                                context:(XmlProcessingContext *)context
                                  error:(NSError *__autoreleasing  _Nullable *)error {
    return [self toKeePassModel:rootNode databaseProperties:databaseProperties context:context minimalAttachmentPool:nil iconPool:@{} error:error];
}

- (RootXmlDomainObject*)toKeePassModel:(Node*)rootNode
                    databaseProperties:(KeePassDatabaseWideProperties*)databaseProperties
                               context:(XmlProcessingContext*)context
                 minimalAttachmentPool:(NSArray<DatabaseAttachment*>**)minimalAttachmentPool
                              iconPool:(NSDictionary<NSUUID*, NodeIcon*>*)iconPool
                                 error:(NSError **)error {
    RootXmlDomainObject *ret = [[RootXmlDomainObject alloc] initWithDefaultsAndInstantiatedChildren:context];

    Meta* originalMeta = databaseProperties.originalMeta;

    if(originalMeta && originalMeta.unmanagedChildren) {
        for (id<XmlParsingDomainObject> child in originalMeta.unmanagedChildren) {
            [ret.keePassFile.meta addUnknownChildObject:child];
        }
    }

    

    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    
    KeePassGroup* rootXmlGroup = [adaptor toKeePassModel:rootNode context:context minimalAttachmentPool:minimalAttachmentPool iconPool:iconPool error:error];

    if(!rootXmlGroup) {
        NSLog(@"Could not serialize groups/entries.");
        return nil;
    }

    ret.keePassFile.root.rootGroup = rootXmlGroup;

    

    ret.keePassFile.meta.generator = kStrongboxGenerator;
    ret.keePassFile.meta.recycleBinEnabled = databaseProperties.metadata.recycleBinEnabled;
    ret.keePassFile.meta.recycleBinGroup = databaseProperties.metadata.recycleBinGroup;
    ret.keePassFile.meta.recycleBinChanged = databaseProperties.metadata.recycleBinChanged;
    ret.keePassFile.meta.historyMaxItems = databaseProperties.metadata.historyMaxItems;
    ret.keePassFile.meta.historyMaxSize = databaseProperties.metadata.historyMaxSize;
    ret.keePassFile.meta.customData.dictionary = databaseProperties.metadata.customData;
    ret.keePassFile.meta.settingsChanged = databaseProperties.metadata.settingsChanged;
    ret.keePassFile.meta.databaseName = databaseProperties.metadata.databaseName;
    ret.keePassFile.meta.databaseNameChanged = databaseProperties.metadata.databaseNameChanged;
    ret.keePassFile.meta.databaseDescription = databaseProperties.metadata.databaseDescription;
    ret.keePassFile.meta.databaseDescriptionChanged = databaseProperties.metadata.databaseDescriptionChanged;
    ret.keePassFile.meta.defaultUserName = databaseProperties.metadata.defaultUserName;
    ret.keePassFile.meta.defaultUserNameChanged = databaseProperties.metadata.defaultUserNameChanged;
    ret.keePassFile.meta.color = databaseProperties.metadata.color;
    ret.keePassFile.meta.entryTemplatesGroup = databaseProperties.metadata.entryTemplatesGroup;
    ret.keePassFile.meta.entryTemplatesGroupChanged = databaseProperties.metadata.entryTemplatesGroupChanged;

    

    if (databaseProperties.deletedObjects.count && !ret.keePassFile.root.deletedObjects) {
        ret.keePassFile.root.deletedObjects = [[DeletedObjects alloc] initWithContext:XmlProcessingContext.standardV3Context];
        
    }

    if(ret.keePassFile.root.deletedObjects) {
        [ret.keePassFile.root.deletedObjects.deletedObjects removeAllObjects];
    }

    for (NSUUID* uuid in databaseProperties.deletedObjects.allKeys) {
        DeletedObject* dob = [[DeletedObject alloc] initWithContext:XmlProcessingContext.standardV3Context];
        dob.uuid = uuid;
        dob.deletionTime = databaseProperties.deletedObjects[uuid];
        [ret.keePassFile.root.deletedObjects.deletedObjects addObject:dob];
    }
        
    

    if ( iconPool.count && !ret.keePassFile.meta.customIconList ) {
        ret.keePassFile.meta.customIconList = [[CustomIconList alloc] initWithContext:[XmlProcessingContext standardV3Context]];
    }

    if (ret.keePassFile.meta.customIconList ) {
        [ret.keePassFile.meta.customIconList.icons removeAllObjects];
    }

    for (NSUUID* uuid in iconPool.allKeys) {
        NodeIcon* ci = iconPool[uuid];
        
        CustomIcon *icon = [[CustomIcon alloc] initWithContext:[XmlProcessingContext standardV3Context]];
        
        icon.uuid = uuid;
        icon.data = ci.custom;
        icon.name = ci.name;
        icon.modified = ci.modified;
        
        [ret.keePassFile.meta.customIconList.icons addObject:icon];
    }

    return ret;
}

+ (NSDictionary<NSUUID *,NSDate *> *)getDeletedObjects:(RootXmlDomainObject *)existingRootXmlDocument {
    if (existingRootXmlDocument &&
        existingRootXmlDocument.keePassFile &&
        existingRootXmlDocument.keePassFile.root &&
        existingRootXmlDocument.keePassFile.root.deletedObjects) {
        NSDictionary<NSUUID*, NSArray<DeletedObject*>*>* byUuid = [existingRootXmlDocument.keePassFile.root.deletedObjects.deletedObjects groupBy:^id _Nonnull(DeletedObject * _Nonnull obj) {
            return obj.uuid;
        }];
        
        NSMutableDictionary<NSUUID*, NSDate*> *ret = NSMutableDictionary.dictionary;
        for (NSUUID* uuid in byUuid.allKeys) {
            NSArray<DeletedObject*>* deletes = byUuid[uuid];
            NSArray<DeletedObject*>* sortedDeletes = [deletes sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                DeletedObject* d1 = (DeletedObject*)obj1;
                DeletedObject* d2 = (DeletedObject*)obj2;
                return [d2.deletionTime compare:d1.deletionTime]; 
            }];
            
            ret[uuid] = sortedDeletes.firstObject.deletionTime;
        }
        
        return ret;
    }
    
    return @{};
}

+ (NSDictionary<NSUUID *, NodeIcon *> *)getCustomIcons:(Meta *)meta {
    if ( meta && meta.customIconList ) {
        if ( meta.customIconList.icons ) {
            NSArray<CustomIcon*> *icons = meta.customIconList.icons;
            NSMutableDictionary<NSUUID*, NodeIcon*> *ret = [NSMutableDictionary dictionaryWithCapacity:icons.count];
            for ( CustomIcon* icon in icons ) {
                if ( icon.data != nil ) { 
                    NodeIcon* nodeIcon = [NodeIcon withCustom:icon.data uuid:icon.uuid name:icon.name modified:icon.modified];
                    [ret setObject:nodeIcon forKey:icon.uuid];
                }
            }
        
            return ret;
        }
    }
    
    return [NSMutableDictionary dictionary];
}

+ (NSArray<DatabaseAttachment*>*)getV3Attachments:(RootXmlDomainObject*)xmlDoc {
    NSArray<V3Binary*>* v3Binaries = safeGetBinaries(xmlDoc);
    
    NSMutableArray<DatabaseAttachment*> *attachments = [NSMutableArray array];
    
    NSArray *sortedById = [v3Binaries sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [@(((V3Binary*)obj1).id) compare:@(((V3Binary*)obj2).id)];
    }];
    
    for (V3Binary* binary in sortedById) {
        [attachments addObject:binary.dbAttachment];
    }
    
    return attachments;
}

static NSMutableArray<V3Binary*>* safeGetBinaries(RootXmlDomainObject* root) {
    if(root && root.keePassFile && root.keePassFile.meta && root.keePassFile.meta.v3binaries) {
        return root.keePassFile.meta.v3binaries.binaries;
    }
    
    return [NSMutableArray array];
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    
    
    KeePassFile *keepassFileElement = existingRootXmlDocument == nil ? nil : existingRootXmlDocument.keePassFile;
    Root* rootXml = keepassFileElement == nil ? nil : keepassFileElement.root;
    KeePassGroup *rootXmlGroup = rootXml == nil ? nil : rootXml.rootGroup;
    
    return rootXmlGroup;
}

@end
