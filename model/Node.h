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

NS_ASSUME_NONNULL_BEGIN

@interface Node : NSObject

+ (instancetype)rootGroup;

- (instancetype _Nullable )init NS_UNAVAILABLE;

- (nonnull instancetype)initAsRoot:(nullable NSUUID*)uuid;
- (nonnull instancetype)initAsRoot:(nullable NSUUID*)uuid childRecordsAllowed:(BOOL)childRecordsAllowed;

- (instancetype _Nullable )initAsGroup:(NSString *_Nonnull)title
                                parent:(Node* _Nonnull)parent
             keePassGroupTitleRules:(BOOL)keePassGroupTitleRules
                                  uuid:(NSUUID*_Nullable)uuid;

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
@property (nonatomic, strong, readonly, nonnull) NodeFields *fields;
@property (nonatomic, weak, readonly, nullable) Node* parent;

@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* children;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* childGroups;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* childRecords;

@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* allChildren;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* allChildRecords;
@property (nonatomic, strong, readonly, nonnull) NSArray<Node*>* allChildGroups;

@property (readonly) BOOL isUsingKeePassDefaultIcon;
@property (readonly) BOOL expired;
@property (readonly) BOOL nearlyExpired;

+ (Node *_Nullable)deserialize:(NSDictionary *)dict
                        parent:(Node*)parent
        keePassGroupTitleRules:(BOOL)allowDuplicateGroupTitle
                         error:(NSError**)error;

- (NSDictionary *)serialize:(SerializationPackage*)serialization; 

- (NSString*)getSerializationId:(BOOL)groupCanUseUuid; 

- (BOOL)contains:(Node*)test;
- (BOOL)setTitle:(NSString*_Nonnull)title keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)validateAddChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)addChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (BOOL)validateChangeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)changeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (void)moveChild:(NSUInteger)from to:(NSUInteger)to;
- (void)removeChild:(Node*)node; 

- (Node*)clone;
- (Node*)cloneAsChildOf:(Node*)parentNode;
- (Node*)clone:(BOOL)recursive;
- (Node*)cloneForHistory;
- (Node*)duplicate:(NSString*)newTitle; 

- (void)sortChildren:(BOOL)ascending;

- (NSArray<NSString*>*)getTitleHierarchy;

- (Node*_Nullable)getChildGroupWithTitle:(NSString*_Nonnull)title;

- (Node*_Nullable)findFirstChild:(BOOL)recursive predicate:(BOOL (^_Nonnull)(Node* _Nonnull node))predicate;
- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate;

- (void)restoreFromHistoricalNode:(Node*)historicalItem;

- (void)touch; 
- (void)touchAt:(NSDate*)date; 
- (void)touchAt:(BOOL)modified date:(NSDate *)date;

- (void)touch:(BOOL)modified; 
- (void)touch:(BOOL)modified touchParents:(BOOL)touchParents;
- (void)touch:(BOOL)modified touchParents:(BOOL)touchParents date:(NSDate*)date;

- (void)touchLocationChanged;
- (void)touchLocationChanged:(NSDate*)date;

- (void)setModifiedDateExplicit:(NSDate*)modDate setParents:(BOOL)setParents; 

- (BOOL)setTotpWithString:(NSString *)string
         appendUrlToNotes:(BOOL)appendUrlToNotes
               forceSteam:(BOOL)forceSteam;







@property (nonatomic, strong, nullable) NSObject *linkedData;

extern NSComparator finderStyleNodeComparator;

- (BOOL)isSyncEqualTo:(Node*)other;
- (BOOL)preOrderTraverse:(BOOL (^)(Node* node))function; 

@end

NS_ASSUME_NONNULL_END
