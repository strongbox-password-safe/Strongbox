//
//  ViewModel.h
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "Model.h"
#import "UnifiedDatabaseMetadata.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "MacDatabasePreferences.h"
#import "EntryViewModel.h"
#import "NextNavigationConstants.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kNotificationUserInfoKeyNode;
extern NSString* const kNotificationUserInfoKeyBoolParam;

extern NSString* const kModelUpdateNotificationCustomFieldsChanged;
extern NSString* const kModelUpdateNotificationPasswordChanged;
extern NSString* const kModelUpdateNotificationTitleChanged;
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
extern NSString* const kModelUpdateNotificationTagsChanged;
extern NSString* const kModelUpdateNotificationSelectedItemChanged;
extern NSString* const kModelUpdateNotificationDatabasePreferenceChanged;
extern NSString* const kModelUpdateNotificationDatabaseUpdateStatusChanged;
extern NSString* const kModelUpdateNotificationNextGenNavigationChanged;
extern NSString* const kModelUpdateNotificationNextGenSelectedItemsChanged;
extern NSString* const kModelUpdateNotificationNextGenSearchContextChanged;

extern NSString* const kModelUpdateNotificationItemsAdded;
extern NSString* const kModelUpdateNotificationItemEdited;

@interface ViewModel : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initLocked:(NSDocument*)document databaseUuid:(NSString*)databaseUuid;
- (instancetype)initUnlocked:(NSDocument *)document
                databaseUuid:(NSString*)databaseUuid
                       model:(Model *)model;

@property (nonatomic, readonly) MacDatabasePreferences *databaseMetadata;
@property (nonatomic, readonly) UnifiedDatabaseMetadata *metadata;

@property (nonatomic, readonly) NSString *databaseUuid;

@property (nonatomic, readonly, weak) NSDocument*  document;
@property (nonatomic, readonly) BOOL locked;
@property (nonatomic, readonly) NSURL* fileUrl;
@property (nonatomic, readonly) Node* rootGroup;
@property (nonatomic, readonly) BOOL masterCredentialsSet;
@property (nonatomic, readonly) DatabaseFormat format;

@property (nonatomic, readonly, nonnull) NSSet<NodeIcon*>* customIcons;

@property (nonatomic, nullable) CompositeKeyFactors* compositeKeyFactors;

@property (nullable) NSUUID* selectedItem;

@property (nullable, readonly) Model* commonModel;
@property (readonly, nonatomic) DatabaseModel* database;

- (Node*_Nullable)getItemById:(NSUUID*)uuid;

- (BOOL)isDereferenceableText:(NSString*)text;
- (NSString*)dereference:(NSString*)text node:(Node*)node;

- (BOOL)applyModelEditsAndMoves:(EntryViewModel *)editModel toNode:(NSUUID*)nodeId;

- (BOOL)setItemTitle:(Node* )item title:(NSString* )title;
- (void)setItemUsername:(Node*)item username:(NSString*)username;
- (void)setItemEmail:(Node*)item email:(NSString*)email;
- (void)setItemUrl:(Node*)item url:(NSString*)url;
- (void)setItemPassword:(Node*)item password:(NSString*)password;
- (void)setItemNotes:(Node*)item notes:(NSString*)notes;
- (void)setItemExpires:(Node*)item expiry:(NSDate*_Nullable)expiry;

- (void)setGroupExpandedState:(Node*)item expanded:(BOOL)expanded;

- (void)setItemIcon:(Node *)item image:(NSImage*)image;
- (void)setItemIcon:(Node *)item icon:(NodeIcon*_Nullable)icon;
- (void)setItemIcon:(Node *)item icon:(NodeIcon*_Nullable)icon batchUpdate:(BOOL)batchUpdate;

- (void)batchSetIcons:(NSArray<Node*>*)items icon:(NodeIcon*)icon;
- (void)batchSetIcons:(NSDictionary<NSUUID*, NSImage*>*)iconMap;

- (void)deleteHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;
- (void)restoreHistoryItem:(Node*)item historicalItem:(Node*)historicalItem;
    
- (void)removeItemAttachment:(Node*)item filename:(NSString*)filename;
- (void)addItemAttachment:(Node*)item filename:(NSString*)filename attachment:(DatabaseAttachment*)attachment;


- (void)addCustomField:(Node *)item key:(NSString *)key value:(StringValue *)value;
- (void)removeCustomField:(Node *)item key:(NSString *)key;
- (void)editCustomField:(Node*)item
       existingFieldKey:(NSString*_Nullable)existingFieldKey
                    key:(NSString *_Nullable)key
                  value:(StringValue *_Nullable)value;

- (void)setTotp:(Node *)item otp:(NSString *)otp steam:(BOOL)steam;
- (void)clearTotp:(Node *)item;

- (void)addItemTag:(Node* )item tag:(NSString*)tag;
- (void)removeItemTag:(Node* )item tag:(NSString*)tag;



- (BOOL)addItem:(Node*)item parent:(Node*)parent;
- (BOOL)addChildren:(NSArray<Node *>*)children parent:(Node *)parent;
- (BOOL)addNewRecord:(Node *)parentGroup;
- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString*)title;
- (BOOL)addNewGroup:(Node *)parentGroup title:(NSString*)title group:(Node* _Nullable * _Nullable)group;

- (Node*)getDefaultNewEntryNode:(Node *_Nonnull)parentGroup;



- (void)deleteItems:(const NSArray<Node *>*)items;
- (BOOL)recycleItems:(const NSArray<Node *>*)items;
- (BOOL)canRecycle:(Node*_Nonnull)item;



- (BOOL)validateMove:(const NSArray<Node *> *)items destination:(Node*)destination;
- (BOOL)move:(const NSArray<Node *> *)items destination:(Node*)destination;

- (BOOL)launchUrl:(Node*)item;
- (BOOL)launchUrlString:(NSString*)urlString;

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
- (NSString *)getGroupPathDisplayString:(Node *)node rootGroupNameInsteadOfSlash:(BOOL)rootGroupNameInsteadOfSlash;

- (NSString *)getParentGroupPathDisplayString:(Node *)node;

@property (readonly) BOOL recycleBinEnabled; 
@property (readonly, nullable) Node* recycleBinNode;
- (void)createNewRecycleBinNode;
@property (readonly, nullable) Node* keePass1BackupNode;



@property (readonly) NSArray<Node*>* activeRecords;
@property (readonly) NSArray<Node*>* activeGroups;

@property (nonatomic, readonly, copy) NSSet<NSString*> * usernameSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * urlSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * emailSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * customFieldKeySet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * tagSet;
@property (nonatomic, readonly, copy) NSSet<NSString*> * passwordSet;

@property (nonatomic, readonly) NSString * mostPopularUsername;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularUsernames;
@property (nonatomic, readonly) NSString* _Nonnull mostPopularEmail;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularEmails;
@property (nonatomic, readonly) NSArray<NSString*>* mostPopularTags;

@property (nonatomic, readonly) NSString * mostPopularPassword;
@property (nonatomic, readonly) NSInteger numberOfRecords;
@property (nonatomic, readonly) NSInteger numberOfGroups;


@property (nonatomic, copy, nullable) void (^onDeleteHistoryItem)(Node* item, Node* historicalItem);
@property (nonatomic, copy, nullable) void (^onRestoreHistoryItem)(Node* item, Node* historicalItem);

- (NSString *)getHtmlPrintString:(NSString*)databaseName;




@property BOOL showTotp;
@property BOOL showAutoCompleteSuggestions;
@property BOOL showChangeNotifications;
@property BOOL concealEmptyProtectedFields;
@property BOOL lockOnScreenLock;
@property BOOL showAdvancedUnlockOptions;
@property BOOL showQuickView;
@property BOOL showAlternatingRows;
@property BOOL showVerticalGrid;
@property BOOL showHorizontalGrid;
@property NSArray<NSString*>* visibleColumns;
@property BOOL downloadFavIconOnChange;
@property BOOL promptedForAutoFetchFavIcon;
@property BOOL startWithSearch;
@property BOOL outlineViewTitleIsReadonly;
@property BOOL outlineViewEditableFieldsAreReadonly;

@property BOOL showRecycleBinInSearchResults;
@property BOOL showRecycleBinInBrowse;
@property BOOL sortKeePassNodes;

@property BOOL monitorForExternalChanges;
@property NSInteger monitorForExternalChangesInterval;
@property BOOL autoReloadAfterExternalChanges;

@property BOOL autoPromptForConvenienceUnlockOnActivate;

@property BOOL launchAtStartup;
@property BOOL alwaysOpenOffline;
@property BOOL readOnly;
@property BOOL offlineMode;
@property (readonly) BOOL isEffectivelyReadOnly; 



- (BOOL)asyncUpdateAndSync:(AsyncUpdateCompletion _Nullable)completion;
@property (nullable) NSUUID* asyncUpdateId;

- (void)update:(NSViewController*)viewController handler:(void(^)(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error))handler;

- (void)reloadDatabaseFromLocalWorkingCopy:(VIEW_CONTROLLER_PTR)viewController 
                                completion:(void(^_Nullable)(BOOL success))completion;



- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
          browseSortField:(BrowseSortField)browseSortField
               descending:(BOOL)descending
        foldersSeparately:(BOOL)foldersSeparately;

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired
                            includeGroups:(BOOL)includeGroups
                          browseSortField:(BrowseSortField)browseSortField
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately;

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately
                         tieBreakUseTitle:(BOOL)tieBreakUseTitle;

@property KeePassIconSet iconSet;



@property (readonly) OGNavigationContext nextGenNavigationContext;
@property (readonly) NSUUID* nextGenNavigationContextSideBarSelectedGroup;
@property (readonly) NSString* nextGenNavigationContextSelectedTag;
@property (readonly) OGNavigationSpecial nextGenNavigationContextSpecial;

- (void)setNextGenNavigationNone;
- (void)setNextGenNavigation:(OGNavigationContext)context selectedGroup:(NSUUID*_Nullable)selectedGroup;
- (void)setNextGenNavigation:(OGNavigationContext)context tag:(NSString*)tag;
- (void)setNextGenNavigation:(OGNavigationContext)context special:(OGNavigationSpecial)special;



@property NSArray<NSUUID*> *nextGenSelectedItems;



@property NSString* nextGenSearchText;
@property SearchScope nextGenSearchScope;

@end

NS_ASSUME_NONNULL_END
