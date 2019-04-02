//
//  OpenSafeView.h
//  StrongBox
//
//  Created by Mark McGuill on 06/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SafeMetaData.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseSafeView : UITableViewController

@property (nonatomic, strong, nonnull) Model *viewModel;
@property (nonatomic, strong, nonnull) Node *currentGroup;

@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonAddGroup;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonAddRecord;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonSafeSettings;
@property (weak, nonatomic, nullable) IBOutlet UIBarButtonItem *buttonMove;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonDelete;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonSortItems;

- (IBAction)onAddGroup:(id _Nullable )sender;
- (IBAction)onAddRecord:(id _Nullable )sender;
- (IBAction)onMove:(id _Nullable)sender;

@end

NS_ASSUME_NONNULL_END
