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

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithSampleData:(Document*_Nonnull)document;
- (instancetype _Nullable )initWithData:(NSData*_Nonnull)data document:(Document*_Nonnull)document;

@property (nonatomic, readonly) Document* _Nonnull document;
@property (nonatomic, readonly) BOOL dirty;
@property (nonatomic, readonly) BOOL locked;
@property (nonatomic, readonly) NSURL* _Nonnull fileUrl;
@property (nonatomic, readonly) Node* _Nonnull rootGroup;
@property (nonatomic, readonly) BOOL masterPasswordIsSet;

- (BOOL)lock:(NSError*_Nonnull*_Nonnull)error selectedItem:(NSString*_Nullable)selectedItem;
- (BOOL)unlock:(NSString*_Nonnull)password selectedItem:(NSString*_Nullable*_Nonnull)selectedItem error:(NSError*_Nonnull*_Nonnull)error;
- (NSData*_Nullable)getPasswordDatabaseAsData:(NSError*_Nonnull*_Nonnull)error;
- (BOOL)setMasterPassword:(NSString*_Nonnull)password;

- (BOOL)setItemTitle:(Node* _Nonnull)item title:(NSString* _Nonnull)title;
- (void)setItemUsername:(Node*_Nonnull)item username:(NSString*_Nonnull)username;
- (void)setItemUrl:(Node*_Nonnull)item url:(NSString*_Nonnull)url;
- (void)setItemPassword:(Node*_Nonnull)item password:(NSString*_Nonnull)password;
- (void)setItemNotes:(Node*_Nullable)item notes:(NSString*_Nonnull)notes;

- (Node*_Nonnull)addNewRecord:(Node *_Nonnull)parentGroup;
- (Node*_Nonnull)addNewGroup:(Node *_Nonnull)parentGroup;

- (void)deleteItem:(Node *_Nonnull)child;

- (BOOL)validateChangeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node;
- (BOOL)changeParent:(Node *_Nonnull)parent node:(Node *_Nonnull)node;

- (Node*_Nullable)getItemFromSerializationId:(NSString*_Nonnull)serializationId;

- (NSString*_Nonnull)generatePassword;

- (NSString*_Nonnull)getDiagnosticDumpString;

- (void)defaultLastUpdateFieldsToNow;

@end
