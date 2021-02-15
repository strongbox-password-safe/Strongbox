//
//  ItemDetailsViewController.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

#ifdef IS_APP_EXTENSION
#import "CredentialProviderViewController.h"
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CellHeightsChangedNotification;
extern NSString *const kNotificationNameItemDetailsEditDone;

@interface ItemDetailsViewController : UITableViewController

+ (NSArray<NSNumber*>*)defaultCollapsedSections;

@property BOOL createNewItem;
@property BOOL editImmediately;

@property NSUUID* parentGroupId;
@property NSUUID*_Nullable itemId;
@property NSNumber*_Nullable historicalIndex;

@property BOOL readOnly;
@property Model* databaseModel;

#ifdef IS_APP_EXTENSION

@property (nonatomic, copy) void (^onAutoFillNewItemAdded)(NSString* username, NSString* password);

@property (nonatomic, nullable) NSString* autoFillSuggestedTitle;
@property (nonatomic, nullable) NSString* autoFillSuggestedUrl;
@property (nonatomic, nullable) NSString* autoFillSuggestedNotes;

#endif

@end

NS_ASSUME_NONNULL_END
