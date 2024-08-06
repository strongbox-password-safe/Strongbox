//
//  Node.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Node.h"
#import "Utils.h"
#import "OTPToken+Serialization.h"
#import "OTPToken+Generation.h"
#import "NSURL+QueryItems.h"
#import "MMcG_MF_Base32Additions.h"
#import "NSArray+Extensions.h"
#import "NSDate+Extensions.h"
#import "NSData+Extensions.h"

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

+ (BOOL)sortTitleLikeFinder:(Node*)a b:(Node*)b {
    return finderStyleNodeComparator(a, b) == NSOrderedAscending;
}

+ (instancetype)rootGroup {
    return [[Node alloc] initAsRoot:nil];
}

+ (instancetype)rootWithDefaultKeePassEffectiveRootGroup {
    Node* rootGroup = Node.rootGroup;

    Node* keePassRootGroup = [[Node alloc] initAsGroup:NSLocalizedString(@"generic_database", @"Database") parent:rootGroup keePassGroupTitleRules:YES uuid:nil];
    
    [rootGroup addChild:keePassRootGroup keePassGroupTitleRules:YES];

    return rootGroup;
}

- (instancetype)initAsRoot:(NSUUID*)uuid {
    return [self initAsRoot:nil childRecordsAllowed:YES];
}

- (instancetype)initAsRoot:(NSUUID*)uuid childRecordsAllowed:(BOOL)childRecordsAllowed {
    return [self initWithParent:nil title:NSLocalizedString(@"generic_database", @"Database") isGroup:YES uuid:uuid fields:nil childRecordsAllowed:childRecordsAllowed];
}

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent
                keePassGroupTitleRules:(BOOL)keePassGroupTitleRules
                                  uuid:(NSUUID*)uuid {
    if (keePassGroupTitleRules) {
        if (!title) {
            title = @""; 
        }
    }
    else {
        if(![title length]) {
            slog(@"Cannot create group with empty title. [%@-%@]", parent.title, title);
            return nil;
        }
    }
    
    for (Node* child in parent.children) {
        if (child.isGroup && !keePassGroupTitleRules && [child.title compare:title] == NSOrderedSame) {
            slog(@"Cannot create group as parent already has a group with this title. [%@-%@]", parent.title, title);
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
        _icon = nil;
        
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
    NSArray<NSDictionary*> *children = dict[@"children"];

    NSNumber *iconId = dict[@"iconId"];
    NSString* customIconData = dict[@"customIconData"];
    NSString* customIconName = dict[@"customIconName"];
    NSNumber* customIconModified = dict[@"customIconModified"];

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
    
    if (customIconData) {
        NSData* d = [[NSData alloc] initWithBase64EncodedString:customIconData options:kNilOptions];
        
        NSDate* modified = (customIconModified != nil) ? [NSDate dateWithTimeIntervalSince1970:customIconModified.doubleValue] : nil;
        ret.icon = [NodeIcon withCustom:d name:customIconName modified:modified];
    }
    else if (iconId != nil) {
        ret.icon = [NodeIcon withPreset:iconId.integerValue];
    }
    
    for (NSDictionary* child in children) {
        Node* childNode = [Node deserialize:child parent:ret keePassGroupTitleRules:allowDuplicateGroupTitle error:error];
        if(!childNode) {
            return nil;
        }
        
        
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
        
    NSArray<NSDictionary*>* childDictionaries = [self.children map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj serialize:serialization];
    }];
    ret[@"children"] = childDictionaries;

    
    
    if (self.icon) {
        if (self.icon.isCustom) {
            ret[@"customIconData"] =  self.icon.custom.base64String;
            
            if ( self.icon.name ) {
                ret[@"customIconName"] = self.icon.name;
            }
            
            if ( self.icon.modified ) {
                ret[@"customIconModified"] = @(self.icon.modified.timeIntervalSince1970);
            }
        }
        else {
            ret[@"iconId"] = @(self.icon.preset);
        }
    }
    
    return ret;
}

- (Node*)duplicate:(NSString*)newTitle preserveTimestamps:(BOOL)preserveTimestamps {
    Node* ret = [self cloneOrDuplicate:preserveTimestamps
                             cloneUuid:NO
                        cloneRecursive:YES
                              newTitle:newTitle
                            parentNode:nil];

    [ret.fields.keePassHistory removeAllObjects];

    return ret;
}

- (Node *)clone {
    return [self clone:NO];
}

- (Node *)cloneAsChildOf:(Node*)parentNode {
    return [self cloneOrDuplicate:YES cloneUuid:YES cloneRecursive:NO newTitle:nil parentNode:parentNode];
}

- (Node *)clone:(BOOL)recursive {
    return [self cloneOrDuplicate:YES cloneUuid:YES cloneRecursive:recursive newTitle:nil parentNode:nil];
}

- (Node *)cloneForHistory {
    Node* ret = [self cloneOrDuplicate:YES cloneUuid:YES cloneRecursive:NO newTitle:nil parentNode:nil];
    [ret.fields.keePassHistory removeAllObjects];
    return ret;
}

- (Node*)cloneOrDuplicate:(BOOL)cloneMetadataDates
                cloneUuid:(BOOL)cloneUuid
           cloneRecursive:(BOOL)cloneRecursive
                 newTitle:(NSString*)newTitle
               parentNode:(Node*_Nullable)parentNode {
    NodeFields* clonedFields = [self.fields cloneOrDuplicate:cloneMetadataDates];
    
    Node* newParent = parentNode ? parentNode : self.parent;
    NSUUID* newUuid = cloneUuid ? self.uuid : nil;
    
    if ( newParent == nil ) {
        
        newUuid = nil;
    }
    
    Node* ret = [[Node alloc] initWithParent:newParent
                                       title:newTitle ? newTitle : self.title
                                     isGroup:self.isGroup
                                        uuid:newUuid
                                      fields:clonedFields
                         childRecordsAllowed:self.childRecordsAllowed];
    
    ret.icon = self.icon;

    if ( cloneUuid ) { 
        
        ret.linkedData = self.linkedData;
    }
    
    if ( ret.isGroup && cloneRecursive ) {
        for (Node* child in self.children) {
            Node* clonedChild = [child cloneOrDuplicate:cloneMetadataDates
                                              cloneUuid:cloneUuid
                                         cloneRecursive:cloneRecursive
                                               newTitle:nil
                                             parentNode:ret];
        
            [ret insertChild:clonedChild keePassGroupTitleRules:YES atPosition:-1];
        }
    }
    
    return ret;
}




- (BOOL)mergePropertiesInFromNode:(Node *)mergeNode 
         mergeLocationChangedDate:(BOOL)mergeLocationChangedDate
                   includeHistory:(BOOL)includeHistory
           keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if (self.isGroup != mergeNode.isGroup) {
        slog(@"WARNWARN: mergePropertiesInFromNode - group not group");
        return NO;
    }

    if (![self setTitle:mergeNode.title keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }
    
    self.icon = mergeNode.icon;
    
    self.linkedData = self.linkedData; 
    
    [self.fields mergePropertiesInFromNode:mergeNode.fields mergeLocationChangedDate:mergeLocationChangedDate includeHistory:includeHistory];
    
    return YES;
}



- (BOOL)isUsingKeePassDefaultIcon {
    if (self.icon == nil) {
        return YES;
    }
    
    if(self.icon.isCustom) {
        return NO;
    }
        
    if(self.icon.preset == -1) {
        return YES;
    }
    
    if(self.isGroup && self.icon.preset == 48) {
        return YES;
    }
    
    if(!self.isGroup && self.icon.preset == 0) {
        return YES;
    }
    
    return NO;
}



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

- (void)setModifiedDateExplicit:(NSDate *)modDate setParents:(BOOL)setParents { 
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
    }] : @[];
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
            title = @""; 
        }
    }
    else if (self.isGroup) {
        if(![title length]) {
            slog(@"setTitle: Cannot have empty group title in non KeePass database.");
            return NO;
        }
    }
    
    if(self.isGroup) {
        for (Node* child in self.parent.children) {
            if (child.isGroup && !keePassGroupTitleRules && [child.title compare:title] == NSOrderedSame) {
                slog(@"Cannot create group as parent already has a group with this title. [%@-%@]", self.parent.title, title);
                return NO;
            }
        }
    }
    
    _title = title;
    
    return YES;
}

- (BOOL)validateAddChild:(Node *)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if ( !node ) {
        slog(@"🔴 Cannot Add: Node is nil.");
        return NO;
    }
        
    
    
    if ( !self.isGroup ) {
        
        return NO;
    }
    
    
    
    if ( !node.isGroup ) {
        return self.childRecordsAllowed;
    }

    
    
    if ( !keePassGroupTitleRules) {
        for (Node* child in self.children) {
            if (child.isGroup && [child.title compare:node.title] == NSOrderedSame) {
                slog(@"🔴 Cannot add child group as we already have a group with this title. [%@-%@]", self.title, node.title);
                return NO;
            }
        }
    }
        
    return YES;
}

- (BOOL)addChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return [self insertChild:node keePassGroupTitleRules:keePassGroupTitleRules atPosition:-1];
}

- (BOOL)insertChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules atPosition:(NSInteger)atPosition {
    if(![self validateAddChild:node keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }

    if ( node.parent != self ) {
        slog(@"🔴 Node parent field is not correctly set to this node. Patching parent, please fix whatever broken code led here...");
        [node internalPatchParent:self];
    }
    
    if (atPosition == -1) { 
        atPosition = _mutableChildren.count;
    }
    else {
        atPosition = MAX(0, atPosition);
        atPosition = MIN(_mutableChildren.count, atPosition);
    }
    
    [_mutableChildren insertObject:node atIndex:atPosition];
    
    return YES;
}

- (BOOL)reorderChild:(Node*)item to:(NSInteger)to keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if (![_mutableChildren containsObject:item]) {
        return NO;
    }
    
    [_mutableChildren removeObject:item];
    return [self insertChild:item keePassGroupTitleRules:YES atPosition:to];
}

- (BOOL)reorderChildAt:(NSUInteger)from to:(NSInteger)to keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if (from >= _mutableChildren.count) {
        return NO;
    }
        
    Node* item = _mutableChildren[from];
    
    return [self reorderChild:item to:to keePassGroupTitleRules:keePassGroupTitleRules];
}

- (void)removeChild:(Node* _Nonnull)node {
    [_mutableChildren removeObject:node];
    [node clearParent];
}

- (void)clearParent {
    _parent = nil;
}

- (void)internalPatchParent:(Node*)parent {
    _parent = parent;
}

- (void)sortChildren:(BOOL)ascending {
    _mutableChildren = [[_mutableChildren sortedArrayUsingComparator:ascending ? finderStyleNodeComparator : reverseFinderStyleNodeComparator] mutableCopy];
}

- (BOOL)validateChangeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return
        parent != self && 
        self.parent != nil && 
    
        
        
        
        
        

        ![parent isChildOf:self] && 
    
        [parent validateAddChild:self keePassGroupTitleRules:keePassGroupTitleRules]; 
}


- (BOOL)changeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    return [self changeParent:parent position:-1 keePassGroupTitleRules:keePassGroupTitleRules];
}

- (BOOL)changeParent:(Node *)parent position:(NSInteger)position keePassGroupTitleRules:(BOOL)keePassGroupTitleRules {
    if(![self validateChangeParent:parent keePassGroupTitleRules:keePassGroupTitleRules]) {
        return NO;
    }
        
    [self.parent removeChild:self];
    
    Node* rollbackParent = self.parent;
    
    _parent = parent;
    
    if([parent insertChild:self keePassGroupTitleRules:keePassGroupTitleRules atPosition:position]) {
        return YES;
    }
    else { 
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

- (Node*)getChildGroupWithTitle:(NSString*)title {
    for(Node* child in self.children) {
        if(child.isGroup && [child.title compare:title] == NSOrderedSame) {
            return child;
        }
    }
    
    return nil;
}

- (Node*_Nullable)firstOrDefault:(BOOL)recursive predicate:(BOOL (^_Nonnull)(Node* _Nonnull node))predicate {
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
                Node* match = [child firstOrDefault:YES predicate:predicate];
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
        return @[];
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

- (BOOL)isSearchable {
    if ( self.isGroup && self.fields.enableSearching != nil ) { 
        return self.fields.enableSearching.boolValue;
    }
    
    Node* parent = self;
    while ( parent != nil ) {
        if ( parent.fields.enableSearching != nil ) { 
            return parent.fields.enableSearching.boolValue;
        }
        parent = parent.parent;
    }
    
    return YES;
}

- (BOOL)preOrderTraverse:(BOOL (^)(Node*))function {
    for ( Node* child in self.childRecords ) {
        if ( !function ( child ) ) {
            return NO;
        }
    }

    for ( Node* child in self.childGroups ) {
        if( !function ( child ) ) {
            return NO;
        }
        
        if ( ![child preOrderTraverse:function] ) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)isSyncEqualTo:(Node *)other { 
    return [self isSyncEqualTo:other isForUIDiffReport:NO];
}

- (BOOL)isSyncEqualTo:(Node *)other isForUIDiffReport:(BOOL)isForUIDiffReport {
    return [self isSyncEqualTo:other isForUIDiffReport:isForUIDiffReport checkHistory:NO];
}

- (BOOL)isSyncEqualTo:(Node *)other isForUIDiffReport:(BOOL)isForUIDiffReport checkHistory:(BOOL)checkHistory {
    
    if (other == nil) {
        return NO;
    }
    
    if ( ![self.uuid isEqual:other.uuid] ) {
        return NO;
    }
        
    if (self.isGroup && !isForUIDiffReport) {
        
        BOOL ret = [other.fields.modified isLaterThan:self.fields.modified]; 



        return !ret; 
    }
    else {
        if ( [self.title compare:other.title] != NSOrderedSame ) {
            return NO;
        }

        if (!( self.isUsingKeePassDefaultIcon && other.isUsingKeePassDefaultIcon ) ) {
            if ( self.icon != nil ) {
                if ( ![self.icon isEqual:other.icon] ) {
                    return NO;
                }
            }
            else if ( other.icon != nil ) {
                if ( ![other.icon isEqual:self.icon] ) {
                    return NO;
                }
            }
            else {
                
            }
        }
            
        return [self.fields isSyncEqualTo:other.fields
                        isForUIDiffReport:(self.isGroup && isForUIDiffReport)
                             checkHistory:!self.isGroup && checkHistory];
    }
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
    Node* match = [self firstOrDefault:YES predicate:^BOOL(Node * _Nonnull node) {
        return node == test;
    }];
    
    return match != nil;
}

- (void)restoreFromHistoricalNode:(Node *)historicalItem {
    [self setTitle:historicalItem.title keePassGroupTitleRules:YES];

    self.icon = historicalItem.icon;
    
    [self.fields restoreFromHistoricalNode:historicalItem.fields];
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
                NSString* filename = child.fields.attachments.allKeys.firstObject;
                
                KeePassAttachmentAbstractionLayer* a = child.fields.attachments[filename];

                attachmentString = [NSString stringWithFormat:@"(attachment: [%@] length: [%@] digestHash: %@)", filename, friendlyFileSizeString(a.length), a.digestHash];
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
               forceSteam:(BOOL)forceSteam
          addLegacyFields:(BOOL)addLegacyFields
            addOtpAuthUrl:(BOOL)addOtpAuthUrl {
    OTPToken* token = [NodeFields getOtpTokenFromString:string
                                             forceSteam:forceSteam];
    
    if(token) {
        [self.fields setTotp:token appendUrlToNotes:appendUrlToNotes addLegacyFields:addLegacyFields addOtpAuthUrl:addOtpAuthUrl];
        return YES;
    }
    
    return NO;
}



- (NSUInteger)estimatedSize {
    return [self getEstimatedSize:NO];
}

- (NSUInteger)getEstimatedSize:(BOOL)historyItem {
    
    NSUInteger fixedStructuralSizeGuess = 256;
    
    NSUInteger basicFields = self.title.length +
    self.fields.username.length +
    self.fields.password.length +
    self.fields.url.length +
    self.fields.notes.length;
    
    NSUInteger customFields = 0;
    for (NSString* key in self.fields.customFields.allKeys) {
        customFields += key.length + self.fields.customFields[key].value.length;
    }
            
    NSUInteger iconSize = 0;
    NSUInteger binariesSize = 0;
    NSUInteger historySize = 0;

    if ( !historyItem ) {
        
        
        iconSize = self.icon ? self.icon.estimatedStorageBytes : 0UL;
            
        
        
        for (NSString* filename in self.fields.attachments.allKeys) {
            KeePassAttachmentAbstractionLayer* dbA = self.fields.attachments[filename];
            binariesSize += dbA == nil ? 0 : dbA.estimatedStorageBytes;
        }
        
        
        
        
        for (Node* historyNode in self.fields.keePassHistory) {
            historySize += [historyNode getEstimatedSize:YES];
        }
    }

    NSUInteger textSize = basicFields + customFields; 

    NSUInteger ret = fixedStructuralSizeGuess + textSize + historySize + iconSize + binariesSize;

    

    return ret;
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
