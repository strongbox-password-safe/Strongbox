//
//  Node.h
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NodeFields.h"
#import "OTPToken.h"

@interface Node : NSObject

+ (instancetype)rootGroup;

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (nonnull instancetype)initAsRoot:(nullable NSUUID*)uuid;
- (nonnull instancetype)initAsRoot:(NSUUID*)uuid childRecordsAllowed:(BOOL)childRecordsAllowed;

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent
                                  uuid:(nullable NSUUID*)uuid;

- (nonnull instancetype)initAsRecord:(NSString *_Nonnull)title
                              parent:(Node* _Nonnull)parent;

- (nonnull instancetype)initAsRecord:(NSString *_Nonnull)title
                                 parent:(Node* _Nonnull)parent
                                 fields:(NodeFields*_Nonnull)fields
                                   uuid:(nullable NSUUID*)uuid;

- (nonnull instancetype)initWithParent:(nullable Node*)parent
                         title:(nonnull NSString*)title
                       isGroup:(BOOL)isGroup
                          uuid:(nullable NSUUID*)uuid
                        fields:(nullable NodeFields*)fields
           childRecordsAllowed:(BOOL)childRecordsAllowed NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) BOOL isGroup;
@property (nonatomic, readonly) BOOL childRecordsAllowed;

@property (nonatomic, strong, readonly, nonnull) NSString *title;
@property (nonatomic, strong, readonly, nonnull) NSUUID *uuid;

@property (nullable) NSNumber* iconId;
@property (nullable) NSUUID* customIconUuid;

@property (nonatomic, strong, readonly, nonnull) NSString *serializationId; // Must remain save across serializations
@property (nonatomic, strong, readonly, nonnull) NodeFields *fields;
@property (nonatomic, strong, readonly, nullable) Node* parent;

@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* children;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* childGroups;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* childRecords;

- (BOOL)contains:(Node*)test;
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

///////////////////////////////////////////////
// For use by any Safe Format Provider
//
// PWSafe uses this to store original record so we don't overwrite unknown fields
// KeePass to store a link back to the original Xml element so we retain unknown attributes/text/elements

@property (nonatomic, strong, nullable) NSObject *linkedData;

extern NSComparator finderStyleNodeComparator;

@end
