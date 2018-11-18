//
//  Node.m
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Node.h"
#import "Utils.h"

@interface Node ()

@property (nonatomic, strong) NSMutableArray<Node*> *mutableChildren;

@end

@implementation Node

static NSComparator compareNodes = ^(id obj1, id obj2)
{
    Node* n1 = (Node*)obj1;
    Node* n2 = (Node*)obj2;
    
    if(n1.isGroup && !n2.isGroup) {
        return NSOrderedAscending;
    }
    else if(!n1.isGroup && n2.isGroup) {
        return NSOrderedDescending;
    }

    return [Utils finderStringCompare:n1.title string2:n2.title];
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
                                  uuid:(NSUUID*)uuid {
    if(![title length]) {
        NSLog(@"Cannot create group with empty title. [%@-%@]", parent.title, title);
        return nil;
    }

    for (Node* child in parent.children) {
        if (child.isGroup && [child.title isEqualToString:title]) {
            NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", parent.title, title);
            return nil;
        }
    }
    
    return [self initWithParent:parent title:title isGroup:YES uuid:uuid fields:nil childRecordsAllowed:YES];
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
        
        return self;
    }
    
    return self;
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

- (BOOL)setTitle:(NSString*_Nonnull)title {
    if(![title length]) {
        NSLog(@"setTitle: Cannot have empty title.");
        return NO;
    }
    
    if(self.isGroup) {
        for (Node* child in self.parent.children) {
            if (child.isGroup && [child.title isEqualToString:title]) {
                NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", self.parent.title, title);
                return NO;
            }
        }
    }
    
    _title = title;
    
    [self.parent sortChildren];
    
    return YES;
}

- (void)sortChildren {
    [_mutableChildren sortUsingComparator:compareNodes];
}

- (BOOL)validateAddChild:(Node* _Nonnull)node {
    if(!node) {
        return NO;
    }
    
    if(node.isGroup) {
        for (Node* child in self.children) {
            if (child.isGroup && [child.title isEqualToString:node.title]) {
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

- (BOOL)addChild:(Node* _Nonnull)node {
    if(![self validateAddChild:node]) {
        return NO;
    }

    NSUInteger newIndex = [_mutableChildren indexOfObject:node
                                 inSortedRange:(NSRange){0, [_mutableChildren count]}
                                       options:NSBinarySearchingInsertionIndex
                               usingComparator:compareNodes];
    
    [_mutableChildren insertObject:node atIndex:newIndex];

    return YES;
}

- (void)removeChild:(Node* _Nonnull)node {
    [_mutableChildren removeObject:node];
}

- (BOOL)validateChangeParent:(Node*)parent {
    return  parent != self &&
            self.parent != parent &&
            ![parent isChildOf:self] && [parent validateAddChild:self];
}

- (BOOL)changeParent:(Node*)parent {
    if(![self validateChangeParent:parent]) {
        return NO;
    }
    
    [self.parent removeChild:self];
    
    _parent = parent;
    
    if([parent addChild:self]) {
        [parent sortChildren];
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

- (NSString*)serializationId {
    NSString *identifier;
    if(self.isGroup) {
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
    NSArray<Node*> *match = [self filterChildren:recursive predicate:predicate firstMatchOnly:YES];

    return match.firstObject;
}

- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive
                                predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate {
    return [self filterChildren:recursive predicate:predicate firstMatchOnly:NO];
}

- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive
                                predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate
                           firstMatchOnly:(BOOL)firstMatchOnly {
    if(!self.isGroup) {
        return [NSArray array];
    }

    NSMutableArray<Node*>* matching = [[NSMutableArray alloc] init];

    if(predicate) {
        for(Node* child in _mutableChildren) {
            if(predicate(child)) {
                if(firstMatchOnly) {
                    return [NSArray arrayWithObject:child];
                }
                else {
                    [matching addObject:child];
                }
            }
        }
    }
    else if(firstMatchOnly && _mutableChildren.count > 0) {
        return [NSArray arrayWithObject:_mutableChildren.firstObject];
    }
    else {
        [matching addObjectsFromArray:_mutableChildren];
    }
    
    if(recursive) {
        for(Node* child in _mutableChildren) {
            if(child.isGroup) {
                NSArray<Node*> *bar = [child filterChildren:recursive predicate:predicate firstMatchOnly:firstMatchOnly];
                
                if(firstMatchOnly && bar.count > 0) {
                    return bar;
                }

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
