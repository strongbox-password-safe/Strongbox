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
#import "NodeIcon.h"

NS_ASSUME_NONNULL_BEGIN

@interface EntryViewModel : NSObject

+ (instancetype)demoItem;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTitle:(NSString*)title
                     username:(NSString*)username
                     password:(NSString*)password
                          url:(NSString*)url
                        notes:(NSString*)notes
                        email:(NSString*)email
                      expires:(NSDate*_Nullable)expires
                         tags:(NSSet<NSString*>*_Nullable)tags
                         totp:(OTPToken*_Nullable)totp
                         icon:(NodeIcon*_Nullable)icon
                 customFields:(NSArray<CustomFieldViewModel*>*)customFields
                  attachments:(NSDictionary<NSString*, DatabaseAttachment*>*)attachments
                     metadata:(NSArray<ItemMetadataEntry*>*)metadata
                   hasHistory:(BOOL)hasHistory NS_DESIGNATED_INITIALIZER;

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
@property (readonly) NSArray<NSString*> *tags;

@property BOOL hasHistory;

@end

NS_ASSUME_NONNULL_END
