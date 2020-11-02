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
    
    // Strongbox uses the Root Node as a dummy but KeePass the actual root node is serialized and entries are not allowed
    // to be added to it.
    
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
        // No Proper Root Group found in Xml Model. We'll create one
        
        NSString *rootGroupName = NSLocalizedString(@"generic_database", @"Database");
        if ([rootGroupName isEqualToString:@"generic_database"]) { // If it's not translated use default...
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

    // Times
    
    ret.times.lastAccessTime = group.fields.accessed;
    ret.times.lastModificationTime = group.fields.modified;
    ret.times.creationTime = group.fields.created;
    ret.times.usageCount = group.fields.usageCount;
    ret.times.locationChangedTime = group.fields.locationChanged;

    //
    
    ret.icon = group.iconId;
    ret.customIcon = group.customIconUuid;
    
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

    // Times
    
    ret.times.lastAccessTime = node.fields.accessed;
    ret.times.lastModificationTime = node.fields.modified;
    ret.times.creationTime = node.fields.created;
    ret.times.expiryTime = node.fields.expires;
    ret.times.expires = node.fields.expires != nil;
    ret.times.usageCount = node.fields.usageCount;
    ret.times.locationChangedTime = node.fields.locationChanged;
    
    // Strings
    
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
    
    // Binaries
    
    [ret.binaries removeAllObjects];
    for (NodeFileAttachment *attachment in node.fields.attachments) {
        Binary *xmlBinary = [[Binary alloc] initWithContext:self.xmlParsingContext];
        
        xmlBinary.filename = attachment.filename;
        xmlBinary.index = attachment.index;
        
        [ret.binaries addObject:xmlBinary];
    }
    
    // History
 
    [ret.history.entries removeAllObjects];
    if(!stripHistory) {
        for(Node* historicalNode in node.fields.keePassHistory) {
            Entry* historicalEntry = [self buildXmlEntry:historicalNode stripHistory:YES]; // Just in case we have accidentally left history on a historical entry itself...
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
    
    if(group.customIcon) groupNode.customIconUuid = group.customIcon;
    if(group.icon != nil) groupNode.iconId = group.icon;

    for (id<KeePassGroupOrEntry> child in group.groupsAndEntries) {
        if (child.isGroup) {
            if(![self buildGroup:(KeePassGroup*)child parentNode:groupNode]) {
                NSLog(@"Error Builing Child Group: [%@]", child);
                return NO;
            }
        }
        else {
            Node * entryNode = [self nodeFromEntry:(Entry*)child groupNode:groupNode]; // Original KeePass Document Group...
            
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
                                                        email:@""]; // Not an official Keepass Field!

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
    
    // Tags
    
    fields.tags = childEntry.tags;
    
    // Custom Fields
    
    for (NSString* key in childEntry.customStrings.allKeys) {
        StringValue* value = childEntry.customStrings[key];
        [fields setCustomField:key value:value];
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
