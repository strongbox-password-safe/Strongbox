//
//  ItemDetailsModel.h
//  test-new-ui
//
//  Created by Mark on 19/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CustomFieldViewModel.h"
#import "OTPToken.h"
#import "ItemMetadataEntry.h"
#import "DatabaseAttachment.h"
#import "MutableOrderedDictionary.h"
#import "Node.h"
#import "DatabaseFormat.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface EntryViewModel : NSObject

+ (instancetype)demoItem;

+ (instancetype)fromNode:(Node *)item format:(DatabaseFormat)format model:(Model*)model;

- (BOOL)applyToNode:(Node*)ret
     databaseFormat:(DatabaseFormat)databaseFormat
legacySupplementaryTotp:(BOOL)legacySupplementaryTotp
      addOtpAuthUrl:(BOOL)addOtpAuthUrl;

- (instancetype)init NS_UNAVAILABLE;


- (instancetype)clone;
- (BOOL)isValid;
- (BOOL)isDifferentFrom:(EntryViewModel*)other;

- (void)removeAttachment:(NSString*)filename; 
- (NSUInteger)insertAttachment:(NSString*)filename attachment:(DatabaseAttachment*)attachment;

- (void)removeCustomFieldAtIndex:(NSUInteger)index;
- (NSUInteger)insertCustomField:(CustomFieldViewModel*)field;

@property (nullable) NodeIcon* icon;
@property NSString* title;
@property NSString* username;
@property NSString* password;
@property NSString* url;
@property NSString* notes;
@property NSString* email;
@property (nullable) NSDate* expires;

@property (nullable) OTPToken* totp;
@property (readonly) NSArray<CustomFieldViewModel*> *customFields;
@property (readonly) MutableOrderedDictionary<NSString*, DatabaseAttachment*>* attachments;
@property (readonly) NSArray<ItemMetadataEntry*> *metadata;

- (void)addTag:(NSString*)tag;
- (void)removeTag:(NSString*)tag;
- (void)resetTags:(NSSet<NSString*>*)tags;
@property (readonly) NSArray<NSString*> *tags;

@property BOOL hasHistory;

@property (nullable) NSUUID* parentGroupUuid;

@end

NS_ASSUME_NONNULL_END
