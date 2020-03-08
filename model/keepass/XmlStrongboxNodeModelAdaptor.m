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

    ret.icon = group.iconId;
    ret.customIcon = group.customIconUuid;
    
    [ret.groups removeAllObjects];
    for(Node* childGroup in group.childGroups) {
        [ret.groups addObject:[self buildXmlGroup:childGroup]];
    }

    [ret.entries removeAllObjects];
    for(Node* childEntry in group.childRecords) {
        [ret.entries addObject:[self buildXmlEntry:childEntry stripHistory:NO]];
    }
    
    ret.name = group.title;
    ret.uuid = group.uuid;
    
    return ret;
}

- (Entry*)buildXmlEntry:(Node*)entry stripHistory:(BOOL)stripHistory {
    Entry *ret = [[Entry alloc] initWithContext:self.xmlParsingContext];
  
    NSArray<id<XmlParsingDomainObject>> *unmanagedChildren = (NSArray<id<XmlParsingDomainObject>>*)entry.linkedData;
    if(unmanagedChildren) {
        for (id<XmlParsingDomainObject> unmanagedChild in unmanagedChildren) {
            [ret addUnknownChildObject:unmanagedChild];
        }
    }
    
    ret.uuid = entry.uuid;
    ret.icon = entry.iconId;
    ret.customIcon = entry.customIconUuid;

    // Times
    
    ret.times.lastAccessTime = entry.fields.accessed;
    ret.times.lastModificationTime = entry.fields.modified;
    ret.times.creationTime = entry.fields.created;
    ret.times.expiryTime = entry.fields.expires;
    ret.times.expires = entry.fields.expires != nil;
    ret.times.usageCount = entry.fields.usageCount;
    ret.times.locationChangedTime = entry.fields.locationChanged;
    
    // Strings
    
    [ret removeAllStrings];
    for (NSString* key in entry.fields.customFields.allKeys) {
        StringValue* value = entry.fields.customFields[key];
        [ret setString:key value:value.value protected:value.protected];
    }

    ret.title = entry.title;
    ret.username = entry.fields.username;
    ret.password = entry.fields.password;
    ret.url = entry.fields.url;
    ret.notes = entry.fields.notes;
    
    // Binaries
    
    [ret.binaries removeAllObjects];
    for (NodeFileAttachment *attachment in entry.fields.attachments) {
        Binary *xmlBinary = [[Binary alloc] initWithContext:self.xmlParsingContext];
        
        xmlBinary.filename = attachment.filename;
        xmlBinary.index = attachment.index;
        
        [ret.binaries addObject:xmlBinary];
    }
    
    // History
 
    [ret.history.entries removeAllObjects];
    if(!stripHistory) {
        for(Node* historicalNode in entry.fields.keePassHistory) {
            Entry* historicalEntry = [self buildXmlEntry:historicalNode stripHistory:YES]; // Just in case we have accidentally left history on a historical entry itself...
            [ret.history.entries addObject:historicalEntry];
        }
    }
    
    return ret;
}

- (BOOL)buildGroup:(KeePassGroup*)group parentNode:(Node*)parentNode {
    Node* groupNode = [[Node alloc] initAsGroup:group.name parent:parentNode keePassGroupTitleRules:YES uuid:group.uuid];
    
    if(group.customIcon) groupNode.customIconUuid = group.customIcon;
    if(group.icon != nil) groupNode.iconId = group.icon;

    
    for (KeePassGroup *childGroup in group.groups) {
        if(![self buildGroup:childGroup parentNode:groupNode]) {
            NSLog(@"Error Builing Child Group: [%@]", childGroup);
            return NO;
        }
    }

    for (Entry *childEntry in group.entries) {
        Node * entryNode = [self nodeFromEntry:childEntry groupNode:groupNode]; // Original KeePass Document Group...
        
        if( entryNode == nil ) {
            NSLog(@"Error building node from Entry: [%@]", childEntry);
            return NO;
        }
        
        [groupNode addChild:entryNode keePassGroupTitleRules:YES];
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
    
    fields.created = childEntry.times.creationTime;

    [fields setTouchProperties:childEntry.times.lastAccessTime modified:childEntry.times.lastModificationTime usageCount:childEntry.times.usageCount];

    fields.expires = childEntry.times.expires ? childEntry.times.expiryTime : nil;
    fields.locationChanged = childEntry.times.locationChangedTime;
    
    for (Binary* binary in childEntry.binaries) {
        NodeFileAttachment* attachment = [[NodeFileAttachment alloc] init];
        
        attachment.filename = binary.filename;
        attachment.index = binary.index;
        
        [fields.attachments addObject:attachment];
    }
    
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
