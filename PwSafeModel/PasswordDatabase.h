//
//  PasswordDatabase.h
//
//
//  Created by Mark on 01/09/2015.
//
//

#ifndef _PasswordDatabase_h
#define _PasswordDatabase_h

#import <Foundation/Foundation.h>
#import "SafeItemViewModel.h"

@interface PasswordDatabase : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initNewWithoutPassword;
- (instancetype)initNewWithPassword:(NSString *)password;
- (instancetype)initExistingWithDataAndPassword:(NSData *)data password:(NSString *)password error:(NSError **)ppError;

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Search Safe Helpers

@property (getter = getSearchableItems, readonly, copy) NSArray *searchableItems;

- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group;
- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group withFilter:(NSString *)filter;
- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group withFilter:(NSString *)filter deepSearch:(BOOL)deepSearch;
- (NSArray<SafeItemViewModel*> *)getImmediateSubgroupsForParent:(Group *)group;

// Create / Add

- (SafeItemViewModel *)addRecord:(NSString*)title group:(Group*)group username:(NSString*)username url:(NSString*)url password:(NSString*)password notes:(NSString*)notes;
- (SafeItemViewModel *)addRecord:(Record *)newRecord;
- (SafeItemViewModel *)createGroupWithTitle:(Group *)parentGroup title:(NSString *)title validateOnly:(BOOL)validateOnly;

// Move

- (BOOL)validateMoveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group;
- (BOOL)validateMoveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk;
- (void)moveItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)group;
- (BOOL)moveOrValidateItems:(NSArray<SafeItemViewModel*> *)items destination:(Group *)destination validateOnly:(BOOL)validateOnly;

// Edit

- (SafeItemViewModel *)setItemTitle:(SafeItemViewModel *)item title:(NSString *)title; // Also performs move of group and group items!
- (void)setItemUsername:(SafeItemViewModel *)item username:(NSString*)username;
- (void)setItemUrl:(SafeItemViewModel *)item url:(NSString*)url;
- (void)setItemPassword:(SafeItemViewModel *)item password:(NSString*)password;
- (void)setItemNotes:(SafeItemViewModel *)item notes:(NSString*)notes;

// Delete

- (void)deleteItems:(NSArray *)items;
- (void)deleteItem:(SafeItemViewModel *)item;

// Master Password

@property (nonatomic) NSString *masterPassword;
@property (nonatomic, readonly) NSDate *lastUpdateTime;
@property (nonatomic, readonly) NSString *lastUpdateUser;
@property (nonatomic, readonly) NSString *lastUpdateHost;
@property (nonatomic, readonly) NSString *lastUpdateApp;

// Auto complete helpers

@property (getter = getAllExistingUserNames, readonly, copy) NSSet *allExistingUserNames;
@property (getter = getAllExistingPasswords, readonly, copy) NSSet *allExistingPasswords;
@property (getter = getMostPopularUsername, readonly, copy) NSString *mostPopularUsername;
@property (getter = getMostPopularPassword, readonly, copy) NSString *mostPopularPassword;

@property (readonly, copy) NSString *generatePassword;

- (NSData*)getAsData:(NSError**)error;

+ (BOOL)isAValidSafe:(NSData *)candidate;

// Handy for PasteboardWriter for Drag and Drop

- (NSString*)getSerializationIdForItem:(SafeItemViewModel*)item;
- (SafeItemViewModel*)getItemFromSerializationId:(NSString*)serializationId;

@end

#endif // ifndef _PasswordDatabase_h
