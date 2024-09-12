//
//  PickCredentialsTableViewController.h
//  Strongbox AutoFill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"
#import "CredentialProviderViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^PickCredentialsCompletion)(BOOL userCancelled, Node* _Nullable node, NSString* _Nullable newUsername, NSString* _Nullable newPassword);

@interface PickCredentialsTableViewController : UITableViewController

+ (instancetype)fromStoryboard;

@property (nonatomic, strong) Model *model;
@property NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers;
@property (nonatomic, copy) PickCredentialsCompletion completion;

@property BOOL disableCreateNew;
@property BOOL twoFactorOnly;
@property BOOL alsoRequestFieldSelection;

@end

NS_ASSUME_NONNULL_END
