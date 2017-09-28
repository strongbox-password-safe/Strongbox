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

@property (nonatomic, strong) NSString *uniqueRecordId;
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

- (instancetype)initAsRoot {
    if(self = [super init]) {
        _isGroup = YES;
        _parent = nil;
        _title = @"<ROOT>";
        _mutableChildren = [NSMutableArray array];
        return self;
    }
    
    return self;
}

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent {
    if(self = [super init]) {
        for (Node* child in parent.children) {
            if (child.isGroup && [child.title isEqualToString:title]) {
                NSLog(@"Cannot create group as parent already has a group with this title. [%@-%@]", parent.title, title);
                return nil;
            }
        }
        
        _parent = parent;
        _title = title;
        _isGroup = YES;
        _mutableChildren = [NSMutableArray array];
        _fields = [[NodeFields alloc] init];

        return self;
    }
    
    return self;
}

- (instancetype _Nullable )initAsRecord:(NSString *_Nonnull)title
                                 parent:(Node* _Nonnull)parent
                                 fields:(NodeFields*_Nonnull)fields {
    if(self = [super init]) {
        _parent = parent;
        _title = title;
        _isGroup = NO;
        _mutableChildren = nil;
        _uniqueRecordId = [Node generateUniqueId];
        _fields = fields;

        return self;
    }
    
    return self;
}

- (instancetype _Nullable )initWithExistingPasswordSafe3Record:(Record*_Nonnull)record
                                                        parent:(Node* _Nonnull)parent {
    if(self = [super init]) {
        _isGroup = NO;
        _mutableChildren = nil;
        _fields = [[NodeFields alloc] init];
        _parent = parent;
        _title = record.title;
        
        self.fields.username = record.username;
        self.fields.password = record.password;
        self.fields.url = record.url;
        self.fields.notes = record.notes;
        self.fields.passwordHistory = record.passwordHistory;
        
        self.fields.accessed = record.accessed;
        self.fields.modified = record.modified;
        self.fields.created = record.created;
        self.fields.passwordModified = record.passwordModified;
        
        _uniqueRecordId = record.uuid && record.uuid.length ? record.uuid : [Node generateUniqueId];
        _originalLinkedRecord = record;
        
        return self;
    }
    
    return self;
}

- (NSArray<Node*>*)children {
    return self.isGroup ? _mutableChildren : [NSArray array];
}

- (BOOL)setTitle:(NSString*_Nonnull)title {
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
    return parent != self &&
    self.parent != parent &&
    ![parent isChildOf:self] &&
    [parent validateAddChild:self];
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
        identifier = self.uniqueRecordId;
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
    for(Node* child in self.children) {
        if(predicate(child)) {
            return child;
        }
    }
    
    if(recursive) {
        for(Node* child in self.children) {
            if(child.isGroup) {
                Node* found = [child findFirstChild:recursive predicate:predicate];
                
                if(found) {
                    return found;
                }
            }
        }
    }
    
    return nil;
}

- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate {
    NSMutableArray<Node*> *ret = [NSMutableArray array];
    
    NSArray<Node*>* matching;
    if(predicate) {
        matching = [self.children filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            Node* child = (Node*)evaluatedObject;
            return predicate(child);
        }]];
    }
    else {
        matching = self.children;
    }
    
    [ret addObjectsFromArray:matching];
    
    if(recursive) {
        for(Node* child in self.children) {
            if(child.isGroup) {
                NSArray<Node*> *bar = [child filterChildren:recursive predicate:predicate];
                
                [ret addObjectsFromArray:bar];
            }
        }
    }
    
    return ret;
}

+ (NSString*)generateUniqueId {
    NSUUID *unique = [[NSUUID alloc] init];
    
    return unique.UUIDString;
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


@end
