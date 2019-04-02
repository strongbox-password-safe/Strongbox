//
//  SafeDetailsView.h
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface SafeDetailsView : UITableViewController

@property (nonatomic) Model *viewModel;

@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfGroups;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfRecords;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniqueUsernames;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniquePasswords;
@property (weak, nonatomic) IBOutlet UILabel * labelMostPopularUsername;
@property (weak, nonatomic) IBOutlet UILabel * labelNumberOfUniqueEmails;
@property (weak, nonatomic) IBOutlet UILabel * labelMostPopularEmail;

@property (weak, nonatomic) IBOutlet UILabel *labelExportByEmail;
@property (weak, nonatomic) IBOutlet UILabel *labelChangeMasterPassword;
@property (weak, nonatomic) IBOutlet UILabel *labelChangeKeyFile;
@property (weak, nonatomic) IBOutlet UISwitch *switchReadOnly;

@end

NS_ASSUME_NONNULL_END
