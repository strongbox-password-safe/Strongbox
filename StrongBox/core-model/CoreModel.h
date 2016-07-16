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

@property (readonly)    SafeDatabase *safe;

-(id) initNewWithPassword:(NSString*)password;
-(id) initExistingWithDataAndPassword:(NSData*)data password:(NSString*)password error:(NSError**)ppError;
-(id) initWithSafeDatabase:(SafeDatabase*)safe;

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Search Safe Helpers

-(NSArray*)getSearchableItems;
-(NSArray*)getItemsForGroup:(Group*)group;
-(NSArray*)getItemsForGroup:(Group*)group withFilter:(NSString*)filter;
-(NSArray*)getItemsForGroup:(Group*)group withFilter:(NSString*)filter deepSearch:(BOOL)deepSearch;
-(NSArray*)getSubgroupsForGroup:(Group*)group;

// Edit

-(SafeItemViewModel*)addSubgroupWithUIString:(Group*)parentGroup title:(NSString*)title;

// Move

-(BOOL)validateMoveItems:(NSArray*)items destination:(Group*)group;
-(BOOL)validateMoveItems:(NSArray*)items destination:(Group*)group checkIfMoveIntoSubgroupOfDestinationOk:(BOOL)checkIfMoveIntoSubgroupOfDestinationOk;
-(void)moveItems:(NSArray*)items destination:(Group*)group;
-(BOOL)moveOrValidateItems:(NSArray*)items destination:(Group*)destination validate:(BOOL)validate;

// Rename

-(SafeItemViewModel*)renameItem:(SafeItemViewModel*)item title:(NSString*)title; // Also performs move of group and group items!

// Delete

-(void)deleteItems:(NSArray*)items;

// Auto complete helpers

-(NSSet*)getAllExistingUserNames;
-(NSSet*)getAllExistingPasswords;
-(NSString*)getMostPopularUsername;
-(NSString*)getMostPopularPassword;

-(NSString*)generatePassword;
-(NSData*)getAsData;

@end

#endif
