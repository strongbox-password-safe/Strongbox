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
#import "KeePassAttachmentAbstractionLayer.h"
#import "MutableOrderedDictionary.h"
#import "Node.h"
#import "DatabaseFormat.h"
#import "KeeAgentSshKeyViewModel.h"
#import "AutoFillNewRecordSettings.h"
#import "Model.h"

@class Passkey;

NS_ASSUME_NONNULL_BEGIN

@interface EntryViewModel : NSObject

+ (instancetype)demoItem;

+ (instancetype)newEmptyEntry;

+ (instancetype)newEntryWithDefaults:(AutoFillNewRecordSettings *)settings
                 mostPopularUsername:(NSString*)mostPopularUsername
                   generatedPassword:(NSString*)generatedPassword
                    mostPopularEmail:(NSString*)mostPopularEmail;

+ (instancetype)fromNode:(Node *)item model:(Model*)model;

- (BOOL)applyToNode:(Node*)ret
              model:(Model*)model
legacySupplementaryTotp:(BOOL)legacySupplementaryTotp
      addOtpAuthUrl:(BOOL)addOtpAuthUrl;



- (instancetype)init NS_UNAVAILABLE;

- (instancetype)clone;
- (BOOL)isDifferentFrom:(EntryViewModel*)other;



@property BOOL favourite;

@property (nullable) NodeIcon* icon;
@property NSString* title;
@property NSString* username;
@property NSString* password;
@property NSString* url;
@property NSString* notes;
@property NSString* email;
@property (nullable) NSDate* expires;
@property (nullable) OTPToken* totp;
@property (nullable) NSUUID* parentGroupUuid;



@property (readonly) BOOL sortCustomFields;
@property (readonly) NSSet<NSString*> *existingCustomFieldsKeySet;
@property (readonly) NSArray<CustomFieldViewModel*> *customFieldsFiltered;

- (void)removeCustomFieldAtIndex:(NSUInteger)index;
- (void)addCustomField:(CustomFieldViewModel*)field;
- (void)addCustomField:(CustomFieldViewModel*)field atIndex:(NSUInteger)atIndex;
- (void)moveCustomFieldAtIndex:(NSUInteger)sourceIdx to:(NSUInteger)destinationIdx;



@property (readonly) MutableOrderedDictionary<NSString*, KeePassAttachmentAbstractionLayer*>* filteredAttachments;
@property (readonly) NSSet<NSString*>* reservedAttachmentNames;
- (void)removeAttachment:(NSString*)filename;
- (void)insertAttachment:(NSString*)filename attachment:(KeePassAttachmentAbstractionLayer*)attachment;



- (void)addTag:(NSString*)tag;
- (void)removeTag:(NSString*)tag;
- (BOOL)resetTags:(NSSet<NSString*>*)tags; 
@property (readonly) NSArray<NSString*> *tags;



@property (nullable) KeeAgentSshKeyViewModel* keeAgentSshKey;
- (void)setKeeAgentSshKeyEnabled:(BOOL)enabled;



@property (nullable) Passkey* passkey;

@end

NS_ASSUME_NONNULL_END
