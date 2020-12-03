//
//  KeePassXmlModelAdaptor.m
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlStrongboxNodeModelAdaptor.h"
#import "Utils.h"
#import "KeePassConstants.h"
#import "DatabaseAttachment.h"

@interface XmlStrongboxNodeModelAdaptor ()

@property XmlProcessingContext* xmlParsingContext;

@end

@implementation XmlStrongboxNodeModelAdaptor

- (KeePassGroup*)fromModel:(Node*)rootNode context:(XmlProcessingContext*)context error:(NSError**)error {
    self.xmlParsingContext = context;
    
    
    
    
    if(rootNode.children.count != 1 || ![rootNode.children objectAtIndex:0].isGroup) {
       if(error) {
            *error = [Utils createNSError:@"Unexpected root group. More/Less than 1 child at root or non group at root" errorCode:-1];
        }
        
        NSLog(@"Unexpected root group. More/Less than 1 child at root or non group at root");
        return nil;
    }

    Node* keePassRootGroup = [rootNode.children objectAtIndex:0];    
    return [self buildXmlGroup:keePassRootGroup];
}

- (Node*)toModel:(KeePassGroup*)existingXmlRoot error:(NSError**)error {
    Node* rootNode = [[Node alloc] initAsRoot:nil];
    
    if(existingXmlRoot) {
        if(![self buildGroup:existingXmlRoot parentNode:rootNode]) {
            if(error) {
                *error = [Utils createNSError:@"Problem building Strongbox Node model from KeePass Xml" errorCode:-1];
            }
            NSLog(@"ERROR: building groups.");
            return nil;
        }
    }
    else {
        
        
        NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
        if ([rootGroupName isEqualToString:@"generic_database"]) { 
          rootGroupName = kDefaultRootGroupName;
        }

        Node* keePassRootGroup = [[Node alloc] initAsGroup:rootGroupName parent:rootNode keePassGroupTitleRules:YES uuid:nil];
        [rootNode addChild:keePassRootGroup keePassGroupTitleRules:YES];
    }
    
    return rootNode;
}

- (KeePassGroup*)buildXmlGroup:(Node*)group {
    KeePassGroup *ret = [[KeePassGroup alloc] initWithContext:self.xmlParsingContext];

    NSArray<id<XmlParsingDomainObject>> *unmanagedChildren = (NSArray<id<XmlParsingDomainObject>>*)group.linkedData;
    if(unmanagedChildren) {
        for (id<XmlParsingDomainObject> unmanagedChild in unmanagedChildren) {
            [ret addUnknownChildObject:unmanagedChild];
        }
    }

    
    
    ret.times.lastAccessTime = group.fields.accessed;
    ret.times.lastModificationTime = group.fields.modified;
    ret.times.creationTime = group.fields.created;
    ret.times.usageCount = group.fields.usageCount;
    ret.times.locationChangedTime = group.fields.locationChanged;
    ret.times.expiryTime = group.fields.expires;
    ret.times.expires = group.fields.expires != nil;

    
    
    ret.icon = group.iconId;
    ret.customIcon = group.customIconUuid;
    ret.customData.orderedDictionary = group.fields.customData;
    ret.notes = group.fields.notes;
    ret.defaultAutoTypeSequence = group.fields.defaultAutoTypeSequence;
    ret.enableAutoType = group.fields.enableAutoType;
    ret.enableSearching = group.fields.enableSearching;
    ret.lastTopVisibleEntry = group.fields.lastTopVisibleEntry;

    [ret.groupsAndEntries removeAllObjects];
    for(Node* child in group.children) {
        if (child.isGroup) {
            [ret.groupsAndEntries addObject:[self buildXmlGroup:child]];
        }
        else {
            [ret.groupsAndEntries addObject:[self buildXmlEntry:child stripHistory:NO]];
        }
    }
    
    ret.name = group.title;
    ret.uuid = group.uuid;
    
    return ret;
}

- (Entry*)buildXmlEntry:(Node*)node stripHistory:(BOOL)stripHistory {
    Entry *ret = [[Entry alloc] initWithContext:self.xmlParsingContext];
  
    NSArray<id<XmlParsingDomainObject>> *unmanagedChildren = (NSArray<id<XmlParsingDomainObject>>*)node.linkedData;
    if(unmanagedChildren) {
        for (id<XmlParsingDomainObject> unmanagedChild in unmanagedChildren) {
            [ret addUnknownChildObject:unmanagedChild];
        }
    }
    
    ret.uuid = node.uuid;
    ret.icon = node.iconId;
    ret.customIcon = node.customIconUuid;
    ret.customData.orderedDictionary = node.fields.customData;
    ret.foregroundColor = node.fields.foregroundColor;
    ret.backgroundColor = node.fields.backgroundColor;
    ret.overrideURL = node.fields.overrideURL;
    
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
    for (NodeFileAttachment *attachment in node.fields.attachments) {
        Binary *xmlBinary = [[Binary alloc] initWithContext:self.xmlParsingContext];
        
        xmlBinary.filename = attachment.filename;
        xmlBinary.index = attachment.index;
        
        [ret.binaries addObject:xmlBinary];
    }
    
    
 
    [ret.history.entries removeAllObjects];
    if(!stripHistory) {
        for(Node* historicalNode in node.fields.keePassHistory) {
            Entry* historicalEntry = [self buildXmlEntry:historicalNode stripHistory:YES]; 
            [ret.history.entries addObject:historicalEntry];
        }
    }
    
    ret.tags = node.fields.tags;
    
    return ret;
}

- (BOOL)buildGroup:(KeePassGroup*)group parentNode:(Node*)parentNode {
    Node* groupNode = [[Node alloc] initAsGroup:group.name parent:parentNode keePassGroupTitleRules:YES uuid:group.uuid];
    
    [groupNode.fields setTouchPropertiesWithCreated:group.times.creationTime
                                           accessed:group.times.lastAccessTime
                                           modified:group.times.lastModificationTime
                                    locationChanged:group.times.locationChangedTime
                                         usageCount:group.times.usageCount];

    groupNode.fields.expires = group.times.expires ? group.times.expiryTime : nil;

    if (group.customIcon) groupNode.customIconUuid = group.customIcon;
    if (group.icon != nil) groupNode.iconId = group.icon;
    if (group.customData) [groupNode.fields.customData addAll:group.customData.orderedDictionary];
    
    groupNode.fields.notes = group.notes;
    groupNode.fields.defaultAutoTypeSequence = group.defaultAutoTypeSequence;
    groupNode.fields.enableAutoType = group.enableAutoType;
    groupNode.fields.enableSearching = group.enableSearching;
    groupNode.fields.lastTopVisibleEntry = group.lastTopVisibleEntry;
    
    for (id<KeePassGroupOrEntry> child in group.groupsAndEntries) {
        if (child.isGroup) {
            if(![self buildGroup:(KeePassGroup*)child parentNode:groupNode]) {
                NSLog(@"Error Builing Child Group: [%@]", child);
                return NO;
            }
        }
        else {
            Node * entryNode = [self nodeFromEntry:(Entry*)child groupNode:groupNode]; 
            
            if( entryNode == nil ) {
                NSLog(@"Error building node from Entry: [%@]", child);
                return NO;
            }
            
            [groupNode addChild:entryNode keePassGroupTitleRules:YES];
        }
    }
    
    [parentNode addChild:groupNode keePassGroupTitleRules:YES];

    groupNode.linkedData = group.unmanagedChildren;

    return YES;
}

- (Node*)nodeFromEntry:(Entry *)childEntry groupNode:(Node*)groupNode {
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
    
    for (Binary* binary in childEntry.binaries) {
        NodeFileAttachment* attachment = [[NodeFileAttachment alloc] init];
        
        attachment.filename = binary.filename;
        attachment.index = binary.index;
        
        [fields.attachments addObject:attachment];
    }
    
    
    
    fields.tags = childEntry.tags;
    
    
    
    for (NSString* key in childEntry.customStrings.allKeys) {
        StringValue* value = childEntry.customStrings[key];
        [fields setCustomField:key value:value];
    }

    
    
    if (childEntry.customData) [fields.customData addAll:childEntry.customData.orderedDictionary];

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
    
    
    Node* entryNode = [[Node alloc] initAsRecord:childEntry.title
                                          parent:groupNode
                                          fields:fields
                                            uuid:childEntry.uuid]; 
    
    if(childEntry.customIcon) entryNode.customIconUuid = childEntry.customIcon;
    if(childEntry.icon != nil) entryNode.iconId = childEntry.icon;
    
    if(childEntry.history && childEntry.history.entries) {
        for (Entry* historicalEntry in childEntry.history.entries) {
            Node* historicalEntryNode = [self nodeFromEntry:historicalEntry groupNode:groupNode];
            [fields.keePassHistory addObject:historicalEntryNode];
        }
    }
    
    
    
    entryNode.linkedData = childEntry.unmanagedChildren;
    
    return entryNode;
}

@end
