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
#import <Base32/MF_Base32Additions.h>

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
             allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles
                                  uuid:(NSUUID*)uuid {
    if(![title length]) {
        NSLog(@"Cannot create group with empty title. [%@-%@]", parent.title, title);
        return nil;
    }

    for (Node* child in parent.children) {
        if (child.isGroup && !allowDuplicateGroupTitles && [child.title isEqualToString:title]) {
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

- (Node *)cloneForHistory {
    NodeFields* clonedFields = [self.fields cloneForHistory];
    
    Node* ret = [[Node alloc] initWithParent:self.parent
                                       title:self.title
                                     isGroup:self.isGroup
                                        uuid:self.uuid // Yes, verified with KeePass
                                      fields:clonedFields
                         childRecordsAllowed:self.childRecordsAllowed];
    
    ret.iconId = self.iconId;
    ret.customIconUuid = self.customIconUuid;
    ret.linkedData = self.linkedData;
    
    return ret;
}

/////////////

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

- (BOOL)setTitle:(NSString*_Nonnull)title allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles {
    if(![title length]) {
        NSLog(@"setTitle: Cannot have empty title.");
        return NO;
    }
    
    if(self.isGroup) {
        for (Node* child in self.parent.children) {
            if (child.isGroup && !allowDuplicateGroupTitles && [child.title isEqualToString:title]) {
                NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", self.parent.title, title);
                return NO;
            }
        }
    }
    
    _title = title;
    
    return YES;
}

- (BOOL)validateAddChild:(Node* _Nonnull)node allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles {
    if(!node) {
        return NO;
    }
    
    if(node.isGroup) {
        for (Node* child in self.children) {
            if (child.isGroup && !allowDuplicateGroupTitles && [child.title isEqualToString:node.title]) {
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

- (BOOL)addChild:(Node* _Nonnull)node allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles {
    if(![self validateAddChild:node allowDuplicateGroupTitles:allowDuplicateGroupTitles]) {
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

- (BOOL)validateChangeParent:(Node*)parent allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles {
    return  parent != self &&
            self.parent != parent &&
            ![parent isChildOf:self] && [parent validateAddChild:self allowDuplicateGroupTitles:allowDuplicateGroupTitles];
}

- (BOOL)changeParent:(Node*)parent allowDuplicateGroupTitles:(BOOL)allowDuplicateGroupTitles {
    if(![self validateChangeParent:parent allowDuplicateGroupTitles:allowDuplicateGroupTitles]) {
        return NO;
    }
    
    [self.parent removeChild:self];
    
    _parent = parent;
    
    if([parent addChild:self allowDuplicateGroupTitles:allowDuplicateGroupTitles]) {
        return YES;
    }
    
    return NO;
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
        if(child.isGroup && [child.title isEqualToString:title]) {
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
    [self setTitle:historicalItem.title allowDuplicateGroupTitles:YES];
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
            
            [ret appendFormat:@"%@%@[%@] (username: [%@], password: [%@], url: [%@]) - [%@] - %@\n",
             indent, baseIndent, child.title, child.fields.username, child.fields.password, child.fields.url,
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
        return [NSString stringWithFormat:@"{\n[%@] (username: [%@], password: [%@], url: [%@]) (%lu attachments)\n}",
                self.title, self.fields.username, self.fields.password, self.fields.url, (unsigned long)self.fields.attachments.count];
    }
}

@end
