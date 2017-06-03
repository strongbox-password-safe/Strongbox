//
//  CoreModel.h
//
//
//  Created by Mark on 01/09/2015.
//
//

#ifndef _CoreModel_h
#define _CoreModel_h

#import <Foundation/Foundation.h>
#import "SafeDatabase.h"
#import "SafeItemViewModel.h"

@interface CoreModel : NSObject

@property (readonly) SafeDatabase *safe;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initNewWithPassword:(NSString *)password;
- (instancetype)initExistingWithDataAndPassword:(NSData *)data password:(NSString *)password error:(NSError **)ppError;
- (instancetype)initWithSafeDatabase:(SafeDatabase *)safe NS_DESIGNATED_INITIALIZER;

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Search Safe Helpers

@property (NS_NONATOMIC_IOSONLY, getter = getSearchableItems, readonly, copy) NSArray *searchableItems;
- (NSArray *)getItemsForGroup:(Group *)group;
- (NSArray *)getItemsForGroup:(Group *)group withFilter:(NSString *)filter;
- (NSArray *)getItemsForGroup:(Group *)group withFilter:(NSString *)filter deepSearch:(BOOL)deepSearch;
- (NSArray *)getSubgroupsForGroup:(Group *)group;

// Edit

- (SafeItemViewModel *)addSubgroupWithUIString:(Group *)parentGroup title:(NSString *)title;

// Move

- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group;
- (BOOL)validateMoveItems:(NSArray *)items destination:(Group *)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk;
- (void)moveItems:(NSArray *)items destination:(Group *)group;
- (BOOL)moveOrValidateItems:(NSArray *)items destination:(Group *)destination validate:(BOOL)validate;

// Rename

- (SafeItemViewModel *)renameItem:(SafeItemViewModel *)item title:(NSString *)title; // Also performs move of group and group items!

// Delete

- (void)deleteItems:(NSArray *)items;

// Auto complete helpers

@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingUserNames, readonly, copy) NSSet *allExistingUserNames;
@property (NS_NONATOMIC_IOSONLY, getter = getAllExistingPasswords, readonly, copy) NSSet *allExistingPasswords;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularUsername, readonly, copy) NSString *mostPopularUsername;
@property (NS_NONATOMIC_IOSONLY, getter = getMostPopularPassword, readonly, copy) NSString *mostPopularPassword;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *generatePassword;
@property (NS_NONATOMIC_IOSONLY, getter = getAsData, readonly, copy) NSData *asData;

@end

#endif // ifndef _CoreModel_h
