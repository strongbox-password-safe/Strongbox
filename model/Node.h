//
//  Node.h
//  MacBox
//
//  Created by Mark on 31/08/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NodeFields.h"
#import "OTPToken.h"
#import "SyncComparisonParams.h"
#import "NodeIcon.h"

NS_ASSUME_NONNULL_BEGIN

@interface Node : NSObject

+ (instancetype)rootGroup;
+ (instancetype)rootWithDefaultKeePassEffectiveRootGroup;

- (instancetype)init NS_UNAVAILABLE;

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
@property (readonly) BOOL isSearchable;

@property (nonatomic, strong, readonly, nonnull) NSString *title;
@property (nonatomic, strong, readonly, nonnull) NSUUID *uuid;

@property (nullable) NodeIcon* icon;

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

- (BOOL)contains:(Node*)test;
- (BOOL)setTitle:(NSString*_Nonnull)title keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)validateAddChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;



- (BOOL)addChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)insertChild:(Node* _Nonnull)node keePassGroupTitleRules:(BOOL)keePassGroupTitleRules atPosition:(NSInteger)atPosition;
- (void)removeChild:(Node*)node;

- (Node*_Nullable)firstOrDefault:(BOOL)recursive predicate:(BOOL (^_Nonnull)(Node* _Nonnull node))predicate;
- (NSArray<Node*>*_Nonnull)filterChildren:(BOOL)recursive predicate:(BOOL (^_Nullable)(Node* _Nonnull node))predicate;



- (BOOL)reorderChild:(Node*)item to:(NSInteger)to keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)reorderChildAt:(NSUInteger)from to:(NSInteger)to keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;


- (BOOL)validateChangeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (BOOL)changeParent:(Node*)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)changeParent:(Node*)parent position:(NSInteger)position keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (Node*)clone;
- (Node*)cloneAsChildOf:(Node*)parentNode;
- (Node*)clone:(BOOL)recursive;
- (Node*)cloneForHistory;
- (Node*)duplicate:(NSString*)newTitle preserveTimestamps:(BOOL)preserveTimestamps; 

- (Node*)cloneOrDuplicate:(BOOL)cloneMetadataDates
                cloneUuid:(BOOL)cloneUuid
           cloneRecursive:(BOOL)cloneRecursive
                 newTitle:(NSString*_Nullable)newTitle
               parentNode:(Node*_Nullable)parentNode;

- (BOOL)mergePropertiesInFromNode:(Node *)mergeNode mergeLocationChangedDate:(BOOL)mergeLocationChangedDate includeHistory:(BOOL)includeHistory keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;

- (void)sortChildren:(BOOL)ascending;

- (NSArray<NSString*>*)getTitleHierarchy;

- (Node*_Nullable)getChildGroupWithTitle:(NSString*_Nonnull)title;

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
               forceSteam:(BOOL)forceSteam
          addLegacyFields:(BOOL)addLegacyFields
            addOtpAuthUrl:(BOOL)addOtpAuthUrl;







@property (nonatomic, strong, nullable) NSObject *linkedData;

extern NSComparator finderStyleNodeComparator;
extern NSComparator finderStyleNodeComparatorTyped;
+ (BOOL)sortTitleLikeFinder:(Node*)a b:(Node*)b;

- (BOOL)isSyncEqualTo:(Node*)other;
- (BOOL)isSyncEqualTo:(Node *)other isForUIDiffReport:(BOOL)isForUIDiffReport;
- (BOOL)isSyncEqualTo:(Node *)other isForUIDiffReport:(BOOL)isForUIDiffReport checkHistory:(BOOL)checkHistory;

- (BOOL)preOrderTraverse:(BOOL (^)(Node* node))function; 

@property (readonly) NSUInteger estimatedSize;

@end

NS_ASSUME_NONNULL_END
