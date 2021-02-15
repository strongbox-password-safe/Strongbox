//
//  PinsConfigurationController.h
//  Strongbox-iOS
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface PinsConfigurationController : UITableViewController

@property (weak, nonatomic) IBOutlet UIButton *buttonPinOnOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonDuressPinOnOff;
@property (weak, nonatomic) IBOutlet UIButton *buttonChangePin;
@property (weak, nonatomic) IBOutlet UIButton *buttonChangeDuressPin;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionOpenDummy;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionTechnicalError;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDuressActionRemoveDatabase;

@property (nonatomic, nonnull) Model *viewModel;

@property (weak, nonatomic) IBOutlet UILabel *labelRemoveDatabase;
@property (weak, nonatomic) IBOutlet UILabel *labelRemoveDatabaseWarning;

@end

NS_ASSUME_NONNULL_END
