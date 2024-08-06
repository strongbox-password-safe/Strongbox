//
//  KeePassXmlModelAdaptor.m
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "XmlStrongboxNodeModelAdaptor.h"
#import "Utils.h"
#import "KeePassConstants.h"
#import "KeePassAttachmentAbstractionLayer.h"
#import "NSArray+Extensions.h"
#import "MinimalPoolHelper.h"
#import "NSData+Extensions.h"

@interface XmlStrongboxNodeModelAdaptor ()

@property XmlProcessingContext* xmlParsingContext;

@end

@implementation XmlStrongboxNodeModelAdaptor

- (KeePassGroup *)toKeePassModel:(Node *)rootNode context:(XmlProcessingContext *)context error:(NSError *__autoreleasing  _Nullable *)error {
    return [self toKeePassModel:rootNode context:context minimalAttachmentPool:nil iconPool:@{} error:error];
}

- (KeePassGroup*)toKeePassModel:(Node*)rootNode
                        context:(XmlProcessingContext*)context
          minimalAttachmentPool:(NSArray<KeePassAttachmentAbstractionLayer*>**)minimalAttachmentPool
                       iconPool:(nonnull NSDictionary<NSUUID *,NodeIcon *> *)iconPool
                          error:(NSError *__autoreleasing  _Nullable * _Nullable)error {
    self.xmlParsingContext = context;
    
    
    
    
    if(rootNode.children.count != 1 || ![rootNode.children objectAtIndex:0].isGroup) {
       if(error) {
            *error = [Utils createNSError:@"Unexpected root group. More/Less than 1 child at root or non group at root" errorCode:-1];
        }
        
        slog(@"Unexpected root group. More/Less than 1 child at root or non group at root");
        return nil;
    }

    NSArray<KeePassAttachmentAbstractionLayer*>* attachmentsPool = [MinimalPoolHelper getMinimalAttachmentPool:rootNode];
    if (minimalAttachmentPool) {
        *minimalAttachmentPool = attachmentsPool;
    }

    Node* keePassRootGroup = [rootNode.children objectAtIndex:0];
    
    return [self buildXmlGroup:keePassRootGroup attachmentsPool:attachmentsPool iconPool:iconPool];
}

- (Node*)toStrongboxModel:(KeePassGroup *)existingXmlRoot error:(NSError *__autoreleasing  _Nullable *)error {
    return [self toStrongboxModel:existingXmlRoot attachmentsPool:@[] customIconPool:@{} error:error];
}

- (Node*)toStrongboxModel:(KeePassGroup*)existingXmlRoot
          attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool
           customIconPool:(NSDictionary<NSUUID *, NodeIcon *> *)customIconPool
                    error:(NSError**)error {
    Node* rootNode = [[Node alloc] initAsRoot:nil];
    
    if(existingXmlRoot) {
        if(![self buildGroup:existingXmlRoot parentNode:rootNode attachmentsPool:attachmentsPool customIconPool:customIconPool usedIds:NSMutableSet.set]) {
            if(error) {
                *error = [Utils createNSError:@"Problem building Strongbox Node model from KeePass Xml" errorCode:-1];
            }
            slog(@"ERROR: building groups.");
            return nil;
        }
    }
    else {        
        NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
        Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootNode keePassGroupTitleRules:YES uuid:nil];
        [rootNode addChild:keePassRootGroup keePassGroupTitleRules:YES];
    }
    
    return rootNode;
}

- (KeePassGroup*)buildXmlGroup:(Node*)group attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool iconPool:(NSDictionary<NSUUID*, NodeIcon*>*)iconPool {
    KeePassGroup *ret = [[KeePassGroup alloc] initWithContext:self.xmlParsingContext];
    
    
    
    ret.times.lastAccessTime = group.fields.accessed;
    ret.times.lastModificationTime = group.fields.modified;
    ret.times.creationTime = group.fields.created;
    ret.times.usageCount = group.fields.usageCount;
    ret.times.locationChangedTime = group.fields.locationChanged;
    ret.times.expiryTime = group.fields.expires;
    ret.times.expires = group.fields.expires != nil;

    
    
    if ( group.icon ) {
        if ( group.icon.isCustom ) {
            
            if ( group.icon.uuid == nil || !iconPool[group.icon.uuid] ) {
                slog(@"WARNWARN - Custom Icon is not in pool or is custom but nil UUID - [%@]", group.icon.uuid);
            }
            else {
                ret.customIcon = group.icon.uuid;
                ret.icon = @(48); 
            }
        }
        else {
            ret.icon = @(group.icon.preset);
        }
    }
    
    ret.customData.dictionary = group.fields.customData;
    ret.notes = group.fields.notes;
    ret.defaultAutoTypeSequence = group.fields.defaultAutoTypeSequence;
    ret.enableAutoType = group.fields.enableAutoType;
    ret.enableSearching = group.fields.enableSearching;
    ret.lastTopVisibleEntry = group.fields.lastTopVisibleEntry;

    [ret.groupsAndEntries removeAllObjects];
    for(Node* child in group.children) {
        if (child.isGroup) {
            [ret.groupsAndEntries addObject:[self buildXmlGroup:child attachmentsPool:attachmentsPool iconPool:iconPool]];
        }
        else {
            [ret.groupsAndEntries addObject:[self buildXmlEntry:child stripHistory:NO attachmentsPool:attachmentsPool iconPool:iconPool]];
        }
    }
    
    ret.name = group.title;
    ret.uuid = group.uuid;
    ret.tags = group.fields.tags;
    ret.isExpanded = group.fields.isExpanded;
    ret.previousParentGroup = group.fields.previousParentGroup;
    
    return ret;
}

- (Entry*)buildXmlEntry:(Node*)node stripHistory:(BOOL)stripHistory attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool iconPool:(NSDictionary<NSUUID*, NodeIcon*>*)iconPool {
    Entry *ret = [[Entry alloc] initWithContext:self.xmlParsingContext];
      
    ret.uuid = node.uuid;

    if ( node.icon ) {
        if ( node.icon.isCustom ) {
            
            if ( node.icon.uuid == nil || !iconPool[node.icon.uuid] ) {
                slog(@"WARNWARN - Custom Icon is not in pool or is custom but nil UUID - [%@]", node.icon.uuid);
            }
            else {
                ret.customIcon = node.icon.uuid;
                ret.icon = @(0); 
            }
        }
        else {
            ret.icon = @(node.icon.preset);
        }
    }

    ret.customData.dictionary = node.fields.customData;
    ret.foregroundColor = node.fields.foregroundColor;
    ret.backgroundColor = node.fields.backgroundColor;
    ret.overrideURL = node.fields.overrideURL;
    ret.qualityCheck = node.fields.qualityCheck;
    ret.previousParentGroup = node.fields.previousParentGroup;
    
    if (node.fields.autoType) {
        ret.autoType = [[KeePassXmlAutoType alloc] initWithContext:self.xmlParsingContext];

        ret.autoType.enabled = node.fields.autoType.enabled;
        ret.autoType.dataTransferObfuscation = node.fields.autoType.dataTransferObfuscation;
        ret.autoType.defaultSequence = node.fields.autoType.defaultSequence;
        
        if (node.fields.autoType.asssociations.count) {
            for (AutoTypeAssociation* ass in node.fields.autoType.asssociations) {
                KeePassXmlAutoTypeAssociation* kp = [[KeePassXmlAutoTypeAssociation alloc] initWithContext:self.xmlParsingContext];
                kp.window = ass.window;
                kp.keystrokeSequence = ass.keystrokeSequence;
                [ret.autoType.asssociations addObject:kp];
            }
        }
    }

    
    
    ret.times.lastAccessTime = node.fields.accessed;
    ret.times.lastModificationTime = node.fields.modified;
    ret.times.creationTime = node.fields.created;
    ret.times.expiryTime = node.fields.expires;
    ret.times.expires = node.fields.expires != nil;
    ret.times.usageCount = node.fields.usageCount;
    ret.times.locationChangedTime = node.fields.locationChanged;
    
    
    
    [ret removeAllStrings];
    
    
    
    
    
    
    ret.title = node.title;
    ret.username = node.fields.username;
    ret.password = node.fields.password;
    ret.url = node.fields.url;
    ret.notes = node.fields.notes;
    
    for (NSString* key in node.fields.customFields.allKeys) {
        StringValue* value = node.fields.customFields[key];
        [ret setString:key value:value.value protected:value.protected];
    }

    ret.title = node.title;
    ret.username = node.fields.username;
    ret.password = node.fields.password;
    ret.url = node.fields.url;
    ret.notes = node.fields.notes;
    
    
    
    [ret.binaries removeAllObjects];
    
    for (NSString* filename in node.fields.attachments) {
        KeePassAttachmentAbstractionLayer* attachment = node.fields.attachments[filename];
        NSInteger index = [self getIndexOfAttachmentInPool:attachmentsPool attachment:attachment];
        if (index == -1) {
            slog(@"WARNWARN: Attachment not found in pool!");
            continue;
        }
        
        Binary *xmlBinary = [[Binary alloc] initWithContext:self.xmlParsingContext];
        
        xmlBinary.filename = filename;
        xmlBinary.index = index;
        
        [ret.binaries addObject:xmlBinary];
    }
    
    
 
    [ret.history.entries removeAllObjects];
    if(!stripHistory) {
        for(Node* historicalNode in node.fields.keePassHistory) {
            Entry* historicalEntry = [self buildXmlEntry:historicalNode stripHistory:YES attachmentsPool:attachmentsPool iconPool:iconPool]; 
            [ret.history.entries addObject:historicalEntry];
        }
    }
    
    ret.tags = node.fields.tags;
    
    return ret;
}

- (BOOL)buildGroup:(KeePassGroup*)group
        parentNode:(Node*)parentNode
   attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool
    customIconPool:(NSDictionary<NSUUID *, NodeIcon *> *)customIconPool
           usedIds:(NSMutableSet<NSUUID*>*)usedIds {
    BOOL alreadyUsedId = [usedIds containsObject:group.uuid];
    if ( alreadyUsedId ) {
        slog(@"WARNWARN: %@", group.uuid);
    }
    NSUUID* nodeId = ( alreadyUsedId || group.uuid == nil ) ? NSUUID.UUID : group.uuid; 
    [usedIds addObject:nodeId];
    
    Node* groupNode = [[Node alloc] initAsGroup:group.name parent:parentNode keePassGroupTitleRules:YES uuid:nodeId];
    
    [groupNode.fields setTouchPropertiesWithCreated:group.times.creationTime
                                           accessed:group.times.lastAccessTime
                                           modified:group.times.lastModificationTime
                                    locationChanged:group.times.locationChangedTime
                                         usageCount:group.times.usageCount];

    groupNode.fields.expires = group.times.expires ? group.times.expiryTime : nil;
    
    
    
    groupNode.fields.tags = group.tags;
    
    if ( group.customIcon ) {
        NodeIcon* ni = customIconPool[group.customIcon];
        if ( ni ) {
            groupNode.icon = ni;
        }
        else {
            slog(@"WARNWARN: Custom Icon referenced by node not present in pool [%@]-[%@]", group.uuid, group.customIcon);
        }
    }
    else if ( group.icon != nil ) {
        groupNode.icon = [NodeIcon withPreset:group.icon.integerValue];
    }

    if (group.customData) {
        [groupNode.fields.customData addEntriesFromDictionary:group.customData.dictionary];
    }
    
    groupNode.fields.notes = group.notes;
    groupNode.fields.defaultAutoTypeSequence = group.defaultAutoTypeSequence;
    groupNode.fields.enableAutoType = group.enableAutoType;
    groupNode.fields.enableSearching = group.enableSearching;
    groupNode.fields.lastTopVisibleEntry = group.lastTopVisibleEntry;
    groupNode.fields.isExpanded = group.isExpanded;
    groupNode.fields.previousParentGroup = group.previousParentGroup;
    
    for (id<KeePassGroupOrEntry> child in group.groupsAndEntries) {
        if (child.isGroup) {
            if(![self buildGroup:(KeePassGroup*)child parentNode:groupNode attachmentsPool:attachmentsPool customIconPool:customIconPool usedIds:usedIds]) {
                slog(@"Error Builing Child Group: [%@]", child);
                return NO;
            }
        }
        else {
            Node * entryNode = [self nodeFromEntry:(Entry*)child groupNode:groupNode attachmentsPool:attachmentsPool customIconPool:customIconPool usedIds:usedIds historical:NO]; 
            
            if( entryNode == nil ) {
                slog(@"Error building node from Entry: [%@]", child);
                return NO;
            }
            
            [groupNode addChild:entryNode keePassGroupTitleRules:YES];
        }
    }
    
    [parentNode addChild:groupNode keePassGroupTitleRules:YES];

    return YES;
}

- (Node*)nodeFromEntry:(Entry *)childEntry
             groupNode:(Node*)groupNode
       attachmentsPool:(NSArray<KeePassAttachmentAbstractionLayer *> *)attachmentsPool
        customIconPool:(NSDictionary<NSUUID*, NodeIcon*>*)customIconPool
               usedIds:(NSMutableSet<NSUUID*>*)usedIds
            historical:(BOOL)historical {
    NodeFields *fields = [[NodeFields alloc] initWithUsername:childEntry.username
                                                          url:childEntry.url
                                                     password:childEntry.password
                                                        notes:childEntry.notes
                                                        email:@""]; 

    [fields setTouchPropertiesWithCreated:childEntry.times.creationTime
                                 accessed:childEntry.times.lastAccessTime
                                 modified:childEntry.times.lastModificationTime
                          locationChanged:childEntry.times.locationChangedTime
                               usageCount:childEntry.times.usageCount];

    fields.expires = childEntry.times.expires ? childEntry.times.expiryTime : nil;
    
    for ( Binary* binary in childEntry.binaries ) {
        NSInteger index = binary.index;
        if ( index < 0 || index >= attachmentsPool.count || binary.filename == nil ) {
            slog(@"WARNWARN: Node pointed to no existing attachment in attachments pool [%ld] not in %lu", (long)index, (unsigned long)attachmentsPool.count);
            continue;
        }
            
        KeePassAttachmentAbstractionLayer *dbAttachment = attachmentsPool[index];
        fields.attachments[binary.filename] = dbAttachment;
    }
    
    
    
    fields.tags = childEntry.tags;
    
    
    
    for (NSString* key in childEntry.customStringValues.allKeys) {
        StringValue* value = childEntry.customStringValues[key];
        [fields setCustomField:key value:value];
    }

    
    
    if (childEntry.customData) [fields.customData addEntriesFromDictionary:childEntry.customData.dictionary];

    fields.foregroundColor = childEntry.foregroundColor;
    fields.backgroundColor = childEntry.backgroundColor;
    fields.overrideURL = childEntry.overrideURL;
    
    if (childEntry.autoType) {
        fields.autoType = [[AutoType alloc] init];
        
        fields.autoType.enabled = childEntry.autoType.enabled;
        fields.autoType.dataTransferObfuscation = childEntry.autoType.dataTransferObfuscation;
        fields.autoType.defaultSequence = childEntry.autoType.defaultSequence;
        
        if (childEntry.autoType.asssociations.count) {
            NSMutableArray* ma = NSMutableArray.array;
            for (KeePassXmlAutoTypeAssociation* kpa in childEntry.autoType.asssociations) {
                AutoTypeAssociation* assoc = [[AutoTypeAssociation alloc] init];
                assoc.window = kpa.window;
                assoc.keystrokeSequence = kpa.keystrokeSequence;
                [ma addObject:assoc];
            }
            fields.autoType.asssociations = ma.copy;
        }
    }
    
    fields.qualityCheck = childEntry.qualityCheck;
    fields.previousParentGroup = childEntry.previousParentGroup;
    
    
    
    BOOL alreadyUsedId = [usedIds containsObject:childEntry.uuid];
    if ( alreadyUsedId && !historical ) {
        slog(@"WARNWARN: Duplicated ID: %@", childEntry.uuid);
    }
    NSUUID* nodeId = ((alreadyUsedId && !historical) || childEntry.uuid == nil) ? NSUUID.UUID : childEntry.uuid; 
    [usedIds addObject:nodeId];
    
    Node* entryNode = [[Node alloc] initAsRecord:childEntry.title
                                          parent:groupNode
                                          fields:fields
                                            uuid:nodeId];
    
    if ( childEntry.customIcon ) {
        NodeIcon* ni = customIconPool[childEntry.customIcon];
        if ( ni ) {

            entryNode.icon = ni;
        }
        else {
            slog(@"WARNWARN: Custom Icon referenced by node not present in pool [%@]-[%@]", childEntry.uuid, childEntry.customIcon);
        }
    }
    else if ( childEntry.icon != nil ) {
        entryNode.icon = [NodeIcon withPreset:childEntry.icon.integerValue];
    }
    
    if(childEntry.history && childEntry.history.entries) {
        for (Entry* historicalEntry in childEntry.history.entries) {
            Node* historicalEntryNode = [self nodeFromEntry:historicalEntry groupNode:groupNode attachmentsPool:attachmentsPool customIconPool:customIconPool usedIds:usedIds historical:YES];
            [fields.keePassHistory addObject:historicalEntryNode];
        }
    }
    
    return entryNode;
}

- (NSInteger)getIndexOfAttachmentInPool:(NSArray<KeePassAttachmentAbstractionLayer*>*)attachments attachment:(KeePassAttachmentAbstractionLayer*)attachment {
    int i = 0;
    
    for (KeePassAttachmentAbstractionLayer* a in attachments) {
        if ([a.digestHash isEqualToString:attachment.digestHash]) {
            return i;
        }
        i++;
    }
    
    return -1;
}

@end
