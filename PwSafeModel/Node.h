//
//  Node.h
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Record.h"
#import "NodeFields.h"

@interface Node : NSObject

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (instancetype _Nullable )initAsRoot NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable )initAsRecord:(NSString *_Nonnull)title
                                 parent:(Node* _Nonnull)parent
                                 fields:(NodeFields*_Nonnull)fields NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable )initWithExistingPasswordSafe3Record:(Record*_Nonnull)record
                                                        parent:(Node* _Nonnull)parent NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) BOOL isGroup;
@property (nonatomic, strong, readonly, nonnull) NSString *title;
@property (nonatomic, strong, readonly, nonnull) NSString *serializationId; // Must remain save across serializations
@property (nonatomic, strong, readonly, nonnull) NodeFields *fields;
@property (nonatomic, strong, readonly, nullable) Node* parent;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* children;

- (BOOL)setTitle:(NSString*_Nonnull)title;
- (BOOL)validateAddChild:(Node* _Nonnull)node;
- (BOOL)addChild:(Node* _Nonnull)node;
- (void)removeChild:(Node* _Nonnull)node;
- (BOOL)validateChangeParent:(Node*_Nonnull)parent;
- (BOOL)changeParent:(Node*_Nonnull)parent;


- (NSArray<NSString*>*_Nonnull)getTitleHierarchy;

- (Node*_Nullable)getChildGroupWithTitle:(NSString*_Nonnull)title;

- (Node*_Nullable)findFirstChild:(BOOL)recursive predicate:(BOOL (^_Nonnull)(Node* _Nonnull node))predicate;
- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate;

// Required for any fields we ignore/are not aware of so that we don't overwrite them on save, we carry them here
@property (nonatomic, strong, readonly, nullable) Record *originalLinkedRecord;

@end
