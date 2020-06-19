//
//  Node.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Node.h"
#import "Utils.h"
#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"
#import "NSURL+QueryItems.h"
#import "MMcG_MF_Base32Additions.h"
#import "NSArray+Extensions.h"

@interface Node ()

@property (nonatomic, strong) NSMutableArray<Node*> *mutableChildren;

@end

@implementation Node

NSComparator finderStyleNodeComparator = ^(id obj1, id obj2)
{
    Node* n1 = (Node*)obj1;
    Node* n2 = (Node*)obj2;
    
    if(n1.isGroup && !n2.isGroup) {
        return NSOrderedAscending;
    }
    else if(!n1.isGroup && n2.isGroup) {
        return NSOrderedDescending;
    }
    
    return finderStringCompare(n1.title, n2.title);
};

NSComparator reverseFinderStyleNodeComparator = ^(id obj1, id obj2)
{
    Node* n1 = (Node*)obj1;
    Node* n2 = (Node*)obj2;
    
    if(n1.isGroup && !n2.isGroup) {
        return NSOrderedAscending;
    }
    else if(!n1.isGroup && n2.isGroup) {
        return NSOrderedDescending;
    }
    
    return finderStringCompare(n2.title, n1.title);
};

+ (instancetype)rootGroup {
    return [[Node alloc] initAsRoot:nil];
}

- (instancetype)initAsRoot:(NSUUID*)uuid {
    return [self initAsRoot:nil childRecordsAllowed:YES];
}

- (instancetype)initAsRoot:(NSUUID*)uuid childRecordsAllowed:(BOOL)childRecordsAllowed {
    return [self initWithParent:nil title:@"<ROOT>" isGroup:YES uuid:uuid fields:nil childRecordsAllowed:childRecordsAllowed];
}

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent
                keePassGroupTitleRules:(BOOL)keePassGroupTitleRules
                                  uuid:(NSUUID*)uuid {
    if (keePassGroupTitleRules) {
        if (!title) {
            title = @""; // Possible for empty groups in KeePass - particular when entries are selectively exported to a new database :(
        }
    }
    else {
        if(![title length]) {
            NSLog(@"Cannot create group with empty title. [%@-%@]", parent.title, title);
            return nil;
        }
    }
    
    for (Node* child in parent.children) {
        if (child.isGroup && !keePassGroupTitleRules && [child.title compare:title] == NSOrderedSame) {
            NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", parent.title, title);
            return nil;
        }
    }
    
    return [self initWithParent:parent title:title isGroup:YES uuid:uuid fields:nil childRecordsAllowed:YES];
}

- (instancetype)initAsRecord:(NSString *_Nonnull)title
                      parent:(Node* _Nonnull)parent {
    return [self initWithParent:parent title:title isGroup:NO uuid:nil fields:nil childRecordsAllowed:NO];
}

- (instancetype)initAsRecord:(NSString *_Nonnull)title
                                 parent:(Node* _Nonnull)parent
                                 fields:(NodeFields*_Nonnull)fields
                                    uuid:(NSUUID*)uuid {
    return [self initWithParent:parent title:title isGroup:NO uuid:uuid fields:fields childRecordsAllowed:NO];
}

- (instancetype)initWithParent:(Node*)parent
                         title:(nonnull NSString*)title
                       isGroup:(BOOL)isGroup
                          uuid:(NSUUID*)uuid
                        fields:(NodeFields*)fields
           childRecordsAllowed:(BOOL)childRecordsAllowed {
    if(self = [super init]) {
        _parent = parent;
        _title = title;
        _isGroup = isGroup;
        _mutableChildren = [NSMutableArray array];
        _uuid = uuid == nil ?  [[NSUUID alloc] init] : uuid;
        _fields = fields == nil ? [[NodeFields alloc] init] : fields;
        _childRecordsAllowed = childRecordsAllowed;
        _iconId = nil;
        _customIconUuid = nil;

        return self;
    }
    
    return self;
}

+ (Node *)deserialize:(NSDictionary *)dict
               parent:(Node*)parent
keePassGroupTitleRules:(BOOL)allowDuplicateGroupTitle
                error:(NSError**)error {
    NSDictionary *nodeFieldsDict = dict[@"fields"];
    NSString *title = dict[@"title"];
    NSNumber *isGroup = dict[@"isGroup"];
    NSNumber *iconId = dict[@"iconId"];
    NSArray<NSDictionary*> *children = dict[@"children"];
    NSString* customIconUuid = dict[@"customIconUuid"]; // Needs to be corrected in destination database pool
    
    NodeFields* nodeFields = [NodeFields deserialize:nodeFieldsDict];
    
    Node* ret;
    if(isGroup.boolValue) {
        ret = [[Node alloc] initAsGroup:title parent:parent keePassGroupTitleRules:allowDuplicateGroupTitle uuid:nil];
        
        if(!ret) {
            NSString* errorFormat = NSLocalizedString(@"node_serialization_error_duplicate_group_title_fmt", @"Error message indicating that these item(s) cannot be deserialized to this database because they contain two groups with the same title.");
            if (error) {
                *error = [Utils createNSError:[NSString stringWithFormat:errorFormat, title] errorCode:-24122];
            }
            return nil;
        }
    }
    else {
        ret = [[Node alloc] initAsRecord:title parent:parent fields:nodeFields uuid:nil];
    }
    
    
    ret.iconId = iconId;
    ret.customIconUuid = [[NSUUID alloc] initWithUUIDString:customIconUuid];
    
    for (NSDictionary* child in children) {
        Node* childNode = [Node deserialize:child parent:ret keePassGroupTitleRules:allowDuplicateGroupTitle error:error];
        if(!childNode) {
            return nil;
        }
        
        // Error Check not necessary as done in deserialization above
        [ret addChild:childNode keePassGroupTitleRules:allowDuplicateGroupTitle];
    }
    
    return ret;
}

- (NSDictionary *)serialize:(SerializationPackage*)serialization {
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    
    NSDictionary* fieldsDictionary = [self.fields serialize:serialization];
    ret[@"fields"] = fieldsDictionary;
    ret[@"title"] = self.title;
    ret[@"isGroup"] = @(self.isGroup);
    ret[@"iconId"] = self.iconId;
    
    NSArray<NSDictionary*>* childDictionaries = [self.children map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj serialize:serialization];
    }];
    ret[@"children"] = childDictionaries;
    
    if(self.customIconUuid) {
        ret[@"customIconUuid"] = self.customIconUuid.UUIDString;
        [serialization.usedCustomIcons addObject:self.customIconUuid];
    }
    
    return ret;
}

- (Node*)duplicate:(NSString*)newTitle {
    return [self cloneOrDuplicate:YES cloneMetadataDates:NO cloneUuid:NO cloneRecursive:NO newTitle:newTitle];
}

- (Node *)clone {
    return [self clone:NO];
}

- (Node *)clone:(BOOL)recursive {
    return [self cloneOrDuplicate:NO cloneMetadataDates:YES cloneUuid:YES cloneRecursive:recursive newTitle:nil];
}

- (Node *)cloneForHistory {
    return [self cloneOrDuplicate:YES cloneMetadataDates:YES cloneUuid:YES cloneRecursive:NO newTitle:nil];
}

- (Node*)cloneOrDuplicate:(BOOL)clearHistory
       cloneMetadataDates:(BOOL)cloneMetadataDates
                cloneUuid:(BOOL)cloneUuid
           cloneRecursive:(BOOL)cloneRecursive
                 newTitle:(NSString*)newTitle {
    NodeFields* clonedFields = [self.fields cloneOrDuplicate:clearHistory cloneTouchProperties:cloneMetadataDates];
    
    Node* ret = [[Node alloc] initWithParent:self.parent
                                       title:newTitle.length ? newTitle : self.title
                                     isGroup:self.isGroup
                                        uuid:cloneUuid ? self.uuid : nil
                                      fields:clonedFields
                         childRecordsAllowed:self.childRecordsAllowed];
    
    ret.iconId = self.iconId;
    ret.customIconUuid = self.customIconUuid;
    ret.linkedData = self.linkedData;
    
    if (ret.isGroup && cloneRecursive) {
        for (Node* child in self.children) {
            Node* clonedChild = [child cloneOrDuplicate:clearHistory
                                     cloneMetadataDates:cloneMetadataDates
                                              cloneUuid:cloneUuid
                                         cloneRecursive:cloneRecursive
                                               newTitle:newTitle];
        
            [ret addChild:clonedChild keePassGroupTitleRules:YES];
        }
    }
    
    return ret;
}

- (BOOL)isUsingKeePassDefaultIcon {
    if(self.customIconUuid) {
        return NO;
    }
    
    NSNumber* index = self.iconId;
    if(index == nil) {
        return YES;
    }
    
    if(index.intValue == -1) {
        return YES;
    }
    
    if(self.isGroup && index.intValue == 48) {
        return YES;
    }
    
    if(!self.isGroup && index.intValue == 0) {
        return YES;
    }
    
    return NO;
}

/////////////

- (BOOL)expired {
    return self.fields.expired;
}

- (BOOL)nearlyExpired {
    return self.fields.nearlyExpired;
}

- (void)touch {
    [self touch:NO];
}

- (void)touchAt:(NSDate *)date {
    [self touchAt:NO date:date];
}

- (void)touchAt:(BOOL)modified date:(NSDate *)date {
    [self touch:modified touchParents:YES date:date];
}

- (void)touchLocationChanged {
    [self.fields touchLocationChanged];
}

- (void)touchLocationChanged:(NSDate*)date {
    [self.fields touchLocationChanged:date];
}

- (void)touch:(BOOL)modified {
    [self touch:modified touchParents:YES];
}

- (void)touch:(BOOL)modified date:(NSDate*)date {
    [self touch:modified touchParents:YES date:date];
}

- (void)touch:(BOOL)modified touchParents:(BOOL)touchParents date:(NSDate*)date {
    [self.fields touch:modified date:date];
    
    if(touchParents && self.parent) {
        [self.parent touch:modified date:date];
    }
}

- (void)touch:(BOOL)modified touchParents:(BOOL)touchParents {
    [self.fields touch:modified];
    
    if(touchParents && self.parent) {
        [self.parent touch:modified];
    }
}

- (void)setModifiedDateExplicit:(NSDate *)modDate setParents:(BOOL)setParents { // Used for Undo's in Mac...
    [self.fields setModifiedDateExplicit:modDate];
    
    if(setParents && self.parent) {
        [self.parent setModifiedDateExplicit:modDate setParents:YES];
    }
}

- (NSArray<Node*>*)allChildren {
    return self.isGroup ? [self filterChildren:YES predicate:nil] : [NSArray array];
}

- (NSArray<Node*>*)children {
    return self.isGroup ? [self filterChildren:NO predicate:nil] : [NSArray array];
}

- (NSArray<Node *> *)childGroups {
    return self.isGroup ? [self filterChildren:NO predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }] : [NSArray array];
}

- (NSArray<Node *> *)childRecords {
    return self.isGroup ? [self filterChildren:NO predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }] : [NSArray array];
}

- (NSArray<Node *> *)allChildGroups {
    return self.isGroup ? [self filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }] : @[];
}

- (NSArray<Node *> *)allChildRecords {
    return self.isGroup ? [self filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }] : [NSArray array];
}

- (BOOL)setTitle:(NSString*_Nonnull)title keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if (keePassGroupTitleRules) {
        if (!title) {
            title = @""; // Possible for empty groups in KeePass - particular when entries are selectively exported to a new database :(
        }
    }
    else {
        if(![title length]) {
            NSLog(@"setTitle: Cannot have empty title.");
            return NO;
        }
    }
    
    if(self.isGroup) {
        for (Node* child in self.parent.children) {
            if (child.isGroup && !keePassGroupTitleRules && [child.title compare:title] == NSOrderedSame) {
                NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", self.parent.title, title);
                return NO;
            }
        }
    }
    
    _title = title;
    
    return YES;
}

- (BOOL)validateAddChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if(!node) {
        return NO;
    }
    
    if(node.isGroup) {
        for (Node* child in self.children) {
            if (child.isGroup && !keePassGroupTitleRules && [child.title compare:node.title] == NSOrderedSame) {
                NSLog(@"Cannot add child group as we already have a group with this title. [%@-%@]", self.title, node.title);
                return NO;
            }
        }
    }
    else {
        return self.childRecordsAllowed;
    }
    
    return YES;
}

- (BOOL)addChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if(![self validateAddChild:node keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }

    [_mutableChildren addObject:node];
    
    return YES;
}

- (void)moveChild:(NSUInteger)from to:(NSUInteger)to {
    NSLog(@"moveChild: %lu > %lu", (unsigned long)from, (unsigned long)to);
    if(from == to || from >= _mutableChildren.count || to >= _mutableChildren.count || from < 0 || to < 0) {
        return;
    }
    
    NSLog(@"moveChild Ok: %lu > %lu", (unsigned long)from, (unsigned long)to);
    
    Node* node = _mutableChildren[from];
    [_mutableChildren removeObjectAtIndex:from];
    [_mutableChildren insertObject:node atIndex:to];
}

- (void)removeChild:(Node* _Nonnull)node {
    [_mutableChildren removeObject:node];
}

- (void)sortChildren:(BOOL)ascending {
    _mutableChildren = [[_mutableChildren sortedArrayUsingComparator:ascending ? finderStyleNodeComparator : reverseFinderStyleNodeComparator] mutableCopy];
}

- (BOOL)validateChangeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return  parent != self &&
            self.parent != parent &&
            ![parent isChildOf:self] && [parent validateAddChild:self keePassGroupTitleRules:keePassGroupTitleRules];
}

- (BOOL)changeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if(![self validateChangeParent:parent keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }
    
    [self.parent removeChild:self];
    
    Node* rollbackParent = self.parent;
    
    _parent = parent;
    
    if([parent addChild:self keePassGroupTitleRules:keePassGroupTitleRules]) {
        return YES;
    }
    else { // Should pretty much never happen because we validate above...
        _parent = rollbackParent;
        [rollbackParent addChild:self keePassGroupTitleRules:keePassGroupTitleRules];
        return NO;
    }
}

- (BOOL)isChildOf:(Node*)parent {
    Node* currentParent = self.parent;
    
    while(currentParent != nil) {
        if(currentParent == parent) {
            return YES;
        }
        currentParent = currentParent.parent;
    }
    
    return NO;
}

- (NSString*)getSerializationId:(BOOL)groupCanUseUuid {
    // Try to come up with a way to identify this node across serializations -
    // UUID works for KeePass in both cases, but for Password Safe Groups there
    // is no equivalent of UUID so we use the path

    NSString *identifier;
    if(self.isGroup && !groupCanUseUuid) {
        NSArray<NSString*> *titleHierarchy = [self getTitleHierarchy];

        identifier = [titleHierarchy componentsJoinedByString:@":"];
    }
    else {
        identifier = [self.uuid UUIDString];
    }
    
    return [NSString stringWithFormat:@"%@%@", self.isGroup ? @"G" : @"R",  identifier];
}

- (Node*)getChildGroupWithTitle:(NSString*)title {
    for(Node* child in self.children) {
        if(child.isGroup && [child.title compare:title] == NSOrderedSame) {
            return child;
        }
    }
    
    return nil;
}

- (Node*_Nullable)findFirstChild:(BOOL)recursive predicate:(BOOL (^_Nonnull)(Node* _Nonnull node))predicate {
    if(!self.isGroup) {
        return nil;
    }
    
    if(!predicate) {
        return _mutableChildren.firstObject;
    }
    
    for(Node* child in _mutableChildren) {
        if(predicate(child)) {
            return child;
        }
    }
    
    if(recursive) {
        for(Node* child in _mutableChildren) {
            if(child.isGroup) {
                Node* match = [child findFirstChild:YES predicate:predicate];
                if(match) {
                    return match;
                }
            }
        }
    }
    
    return nil;
}

- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive
                                predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate {
    if(!self.isGroup) {
        return [NSArray array];
    }

    NSMutableArray<Node*>* matching = [[NSMutableArray alloc] init];

    if(predicate) {
        for(Node* child in _mutableChildren) {
            if(predicate(child)) {
                [matching addObject:child];
            }
        }
    }
    else {
        [matching addObjectsFromArray:_mutableChildren];
    }
    
    if(recursive) {
        for(Node* child in _mutableChildren) {
            if(child.isGroup) {
                NSArray<Node*> *bar = [child filterChildren:recursive predicate:predicate];
                [matching addObjectsFromArray:bar];
            }
        }
    }
    
    return matching;
}

- (NSArray<NSString*>*)getTitleHierarchy {
    if(self.parent != nil) {
        NSMutableArray<NSString*> *parentHierarchy = [NSMutableArray arrayWithArray:[self.parent getTitleHierarchy]];
        
        [parentHierarchy addObject:self.title];
        
        return parentHierarchy;
    }
    else {
        return [NSMutableArray array];
    }
}

- (BOOL)contains:(Node*)test {
    Node* match = [self findFirstChild:YES predicate:^BOOL(Node * _Nonnull node) {
        return node == test;
    }];
    
    return match != nil;
}

- (void)restoreFromHistoricalNode:(Node *)historicalItem {
    [self setTitle:historicalItem.title keePassGroupTitleRules:YES];
    self.iconId = historicalItem.iconId;
    self.customIconUuid = historicalItem.customIconUuid;
    self.fields.username = historicalItem.fields.username;
    self.fields.url = historicalItem.fields.url;
    self.fields.password = historicalItem.fields.password;
    self.fields.email = historicalItem.fields.email;
    self.fields.notes = historicalItem.fields.notes;
    self.fields.passwordModified = historicalItem.fields.passwordModified;
    self.fields.attachments = [historicalItem.fields cloneAttachments];
    self.fields.customFields = [historicalItem.fields cloneCustomFields];
    self.fields.expires = historicalItem.fields.expires;
}

- (NSString*)recursiveTreeDescription:(uint32_t)indentLevel {
    NSMutableString *ret = [NSMutableString string];
    
    uint32_t baseIndentSpaces = 4;
    NSString* baseIndent = [[[NSString alloc] init] stringByPaddingToLength:baseIndentSpaces withString:@" " startingAtIndex:0];
    NSString* indent = [[[NSString alloc] init] stringByPaddingToLength:(indentLevel * baseIndentSpaces) withString:baseIndent startingAtIndex:0];
    
    if(self.children.count) {
        [ret appendFormat:@"\n%@{\n", indent];
        
        for (Node* child in self.childRecords) {
            NSString* attachmentString;
            if(child.fields.attachments.count == 1) {
                NodeFileAttachment* a = [child.fields.attachments objectAtIndex:0];
                attachmentString = [NSString stringWithFormat:@"(attachment: [%@] index: %d)", a.filename, a.index];
            }
            else {
                attachmentString = [NSString stringWithFormat:@"(%lu attachments)", (unsigned long)child.fields.attachments.count];
            }
            
            [ret appendFormat:@"%@%@[%@] (username: [%@], url: [%@], tags: [%@]) - [%@] - %@\n",
             indent, baseIndent, child.title, child.fields.username, child.fields.url, child.fields.tags,
             child.fields.created, attachmentString];
        }

        for (Node* child in self.childGroups) {
            [ret appendFormat:@"%@%@[%@]", indent, baseIndent, child.title];
            if(child.children.count) {
                NSString *childString = [child recursiveTreeDescription:indentLevel + 1];
                [ret appendFormat:@"%@", childString];
            }
            else {
                [ret appendString:@"\n"];
            }
        }
        [ret appendFormat:@"%@}\n", indent];
    }
    
    return ret;
}

- (BOOL)setTotpWithString:(NSString *)string
         appendUrlToNotes:(BOOL)appendUrlToNotes
               forceSteam:(BOOL)forceSteam {
    OTPToken* token = [NodeFields getOtpTokenFromString:string
                                             forceSteam:forceSteam
                                                 issuer:self.title
                                               username:self.fields.username];
    
    if(token) {
        [self.fields setTotp:token appendUrlToNotes:appendUrlToNotes];
        return YES;
    }
    
    return NO;
}

- (NSString *)description {
    if(self.isGroup) {
        if(self.children.count) {
            return [NSString stringWithFormat:@"\n[%@]%@", self.title, [self recursiveTreeDescription:0]];
        }
        else {
            return [NSString stringWithFormat:@"\n[%@]\n", self.title];
        }
    }
    else {
        return [NSString stringWithFormat:@"{\n[%@] (username: [%@], url: [%@], tags: [%@]) (%lu attachments)\n}",
                self.title, self.fields.username, self.fields.url, self.fields.tags, (unsigned long)self.fields.attachments.count];
    }
}

@end
