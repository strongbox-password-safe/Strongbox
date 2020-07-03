//
//  ViewModel.h
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Document.h"
#import "Node.h"
#import "CHCSVParser.h"
#import "DatabaseModel.h"
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kModelUpdateNotificationCustomFieldsChanged;
extern NSString* const kModelUpdateNotificationPasswordChanged;
extern NSString* const kModelUpdateNotificationTitleChanged;
extern NSString* const kNotificationUserInfoKeyNode;
extern NSString* const kModelUpdateNotificationUsernameChanged;
extern NSString* const kModelUpdateNotificationEmailChanged;
extern NSString* const kModelUpdateNotificationUrlChanged;
extern NSString* const kModelUpdateNotificationNotesChanged;
extern NSString* const kModelUpdateNotificationIconChanged;
extern NSString* const kModelUpdateNotificationAttachmentsChanged;
extern NSString* const kModelUpdateNotificationTotpChanged;
extern NSString* const kNotificationUserInfoKeyIsBatchIconUpdate;
extern NSString* const kModelUpdateNotificationExpiryChanged;
extern NSString* const kModelUpdateNotificationItemsDeleted;
extern NSString* const kModelUpdateNotificationItemsUnDeleted;
extern NSString* const kModelUpdateNotificationItemsMoved;

@interface ViewModel : NSObject

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype)initUnlockedWithDatabase:(Document *)document database:(DatabaseModel*_Nullable)database selectedItem:(NSString*_Nullable)selectedItem;
- (instancetype)initLocked:(Document*)document;
    
- (void)importRecordsFromCsvRows:(NSArray<CHCSVOrderedDictionary*>*)rows;

- (void)lock:(NSString*_Nullable)selectedItem;
- (void)reloadAndUnlock:(CompositeKeyFactors*)compositeKeyFactors
             completion:(void(^)(BOOL success, NSError*_Nullable error))completion;

- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;

- (void)getPasswordDatabaseAsData:(SaveCompletionBlock)completion;

- (BOOL)setItemTitle:(Node* )item title:(NSString* )title;
- (void)setItemUsername:(Node*)item username:(NSString*)username;
- (void)setItemEmail:(Node*)item email:(NSString*)email;
- (void)setItemUrl:(Node*)item url:(NSString*)url;
- (void)setItemPassword:(Node*)item password:(NSString*)password;
- (void)setItemNotes:(Node*)item notes:(NSString*)notes;
- (void)setItemExpires:(Node*)item expiry:(NSDate*_Nullable)expiry;

- (void)setItemIcon:(Node *)item customImage:(NSImage *)customImage;

- (void)setItemIcon:(Node *)item
              index:(NSNumber*_Nullable)index
     existingCustom:(NSUUID*_Nullable)existingCustom
             custom:(NSData*_Nullable)custom;

- (void)setItemIcon:(Node *)item
              index:(NSNumber*_Nullable)index
     existingCustom:(NSUUID*_Nullable)existingCustom
             custom:(NSData*_Nullable)custom
        rationalize:(BOOL)rationalize
        batchUpdate:(BOOL)batchUpdate;

- (void)batchSetIcons:(NSDictionary<NSUUID*, NSImage*>*)iconMap;

- (void)deleteHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;
- (void)restoreHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;
    
- (void)removeItemAttachment:(Node*)item atIndex:(NSUInteger)atIndex;

- (void)addItemAttachment:(Node*)item attachment:(UiAttachment*)attachment;
- (void)addItemAttachment:(Node*)item attachment:(UiAttachment*)attachment rationalize:(BOOL)rationalize;

- (void)setCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value;
- (void)removeCustomField:(Node *)item key:(NSString *)key;

- (void)setTotp:(Node *)item otp:(NSString *)otp steam:(BOOL)steam;
- (void)clearTotp:(Node *)item;

// Additions

- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent keePassGroupTitleRules:(BOOL)keePassGroupTitleRules;
- (BOOL)addNewRecord:(Node *)parentGroup;
- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString*)title;

// Delete

- (void)deleteItems:(const NSArray<Node *>*)items;
- (BOOL)recycleItems:(const NSArray<Node *>*)items;
- (BOOL)canRecycle:(Node*_Nonnull)item;

// Moves

- (BOOL)validateMove:(const NSArray<Node *> *)items destination:(Node*)destination;
- (BOOL)move:(const NSArray<Node *> *)items destination:(Node*)destination;

//

- (NSSet<Node*>*)getMinimalNodeSet:(const NSArray<Node*>*)nodes;
- (Node*_Nullable)getItemFromSerializationId:(NSString*)serializationId;

- (NSString*)generatePassword;

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference;
- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText;

- (NSString *)getGroupPathDisplayString:(Node *)node;

@property (nonatomic, readonly, weak) Document*  document;
@property (nonatomic, readonly) BOOL locked;
@property (nonatomic, readonly) NSURL*  fileUrl;
@property (nonatomic, readonly) Node*  rootGroup;
@property (nonatomic, readonly) BOOL masterCredentialsSet;
@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly, nonnull) NSArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly, nonnull) NSDictionary<NSUUID*, NSData*>* customIcons;

@property (nonatomic) CompositeKeyFactors* compositeKeyFactors;

@property (readonly) BOOL recycleBinEnabled; // Read-Only until we allow config
@property (readonly) Node* recycleBinNode;
- (void)createNewRecycleBinNode;

@property (readonly) Node* keePass1BackupNode;

// Convenience / Summary

@property (readonly) NSArray<Node*>* activeRecords;
@property (readonly) NSArray<Node*>* activeGroups;

@property (nonatomic, readonly, copy) NSSet<NSString*> * usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * urlSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * passwordSet;
@property (nonatomic, readonly) NSString * mostPopularUsername;
@property (nonatomic, readonly) NSString * mostPopularPassword;
@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;

// TODO: Move to notificationcenter 
@property (nonatomic, copy, nullable) void (^onNewItemAdded)(Node* node, BOOL openEntryDetailsWindowWhenDone);
@property (nonatomic, copy, nullable) void (^onDeleteHistoryItem)(Node* item, Node* historicalItem);
@property (nonatomic, copy, nullable) void (^onRestoreHistoryItem)(Node* item, Node* historicalItem);

@property (nullable) NSString* selectedItem;

- (NSString *)getHtmlPrintString:(NSString*)databaseName;

@property (readonly, nonatomic) DatabaseMetadata* databaseMetadata;

- (void)setDatabaseMetadata:(DatabaseMetadata * _Nonnull)databaseMetadata;

@end

NS_ASSUME_NONNULL_END
