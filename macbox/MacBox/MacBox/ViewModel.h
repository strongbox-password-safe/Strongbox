//
//  ViewModel.h
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PasswordDatabase.h"
#import "Document.h"

@interface ViewModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initNewWithSampleData:(Document*)document;
- (instancetype)initWithData:(NSData*)data document:(Document*)document;

@property (nonatomic, readonly) Document* document;
@property (nonatomic, readonly) BOOL dirty;
@property (nonatomic, readonly) BOOL locked;
@property (nonatomic, readonly) NSURL* fileUrl;

- (BOOL)lock:(NSError**)error selectedItem:(NSString*)selectedItem;
- (BOOL)unlock:(NSString*)password selectedItem:(NSString**)selectedItem error:(NSError**)error;

- (NSArray<SafeItemViewModel*> *)getItemsForGroup:(Group *)group;

@property (nonatomic, readonly) BOOL masterPasswordIsSet;
- (NSData*)getPasswordDatabaseAsData:(NSError**)error;

- (BOOL)setMasterPassword:(NSString*)password;
- (SafeItemViewModel*)setItemTitle:(SafeItemViewModel*)item title:(NSString*)title;
- (void)setItemUsername:(SafeItemViewModel*)item username:(NSString*)username;
- (void)setItemUrl:(SafeItemViewModel*)item url:(NSString*)url;
- (void)setItemPassword:(SafeItemViewModel*)item password:(NSString*)password;
- (void)setItemNotes:(SafeItemViewModel*)item notes:(NSString*)notes;

- (SafeItemViewModel*)addNewRecord:(Group *)group;
- (SafeItemViewModel*)addNewGroup:(Group *)parentGroup;

- (void)deleteItem:(SafeItemViewModel*)item;


- (BOOL)validateMoveOfItems:(NSArray<SafeItemViewModel *> *)items group:(SafeItemViewModel*)group;
- (BOOL)moveItems:(NSArray<SafeItemViewModel *> *)items group:(SafeItemViewModel*)group;

- (NSString*)getSerializationIdForItem:(SafeItemViewModel*)item;
- (SafeItemViewModel*)getItemFromSerializationId:(NSString*)serializationId;

- (NSString*)generatePassword;

@end
