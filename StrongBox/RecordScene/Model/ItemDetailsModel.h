//
//  ItemDetailsModel.h
//  test-new-ui
//
//  Created by Mark on 19/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CustomFieldViewModel.h"
#import "UiAttachment.h"
#import "SetIconModel.h"
#import "OTPToken.h"
#import "ItemMetadataEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface ItemDetailsModel : NSObject

+ (instancetype)demoItem;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTitle:(NSString*)title
                     username:(NSString*)username
                     password:(NSString*)password
                          url:(NSString*)url
                        notes:(NSString*)notes
                        email:(NSString*)email
                         totp:(OTPToken*_Nullable)totp
                         icon:(SetIconModel*)icon
                 customFields:(NSArray<CustomFieldViewModel*>*)customFields
                  attachments:(NSArray<UiAttachment*>*)attachments
                     metadata:(NSArray<ItemMetadataEntry*>*)metadata
                   hasHistory:(BOOL)hasHistory NS_DESIGNATED_INITIALIZER;

- (instancetype)clone;
- (BOOL)isValid;
- (BOOL)isDifferentFrom:(ItemDetailsModel*)other;

- (void)removeCustomFieldAtIndex:(NSUInteger)index;
- (NSUInteger)insertCustomField:(CustomFieldViewModel*)field;

- (NSUInteger)insertAttachment:(UiAttachment*)attachment;
- (void)removeAttachmentAtIndex:(NSUInteger)index;

@property SetIconModel* icon;
@property NSString* title;
@property NSString* username;
@property NSString* password;
@property NSString* url;
@property NSString* notes;
@property NSString* email;
@property (nullable) OTPToken* totp;
@property (readonly) NSArray<CustomFieldViewModel*> *customFields;
@property (readonly) NSArray<UiAttachment*> *attachments;
@property (readonly) NSArray<ItemMetadataEntry*> *metadata;
@property BOOL hasHistory; 

@end

NS_ASSUME_NONNULL_END
