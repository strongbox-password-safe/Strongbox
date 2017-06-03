//
//  SafeDetailsAndSettingsView.h
//  StrongBox
//
//  Created by Mark McGuill on 04/07/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

@interface SafeDetailsAndSettingsView : UIViewController

@property (nonatomic) Model *viewModel;

@property (weak, nonatomic) IBOutlet UILabel *labelUpdateUser;
@property (weak, nonatomic) IBOutlet UILabel *labelUpdateHost;
@property (weak, nonatomic) IBOutlet UILabel *labelUpdateTime;
@property (weak, nonatomic) IBOutlet UILabel *labelUpdateApp;

@property (weak, nonatomic) IBOutlet UIButton *buttonTouchId;
@property (weak, nonatomic) IBOutlet UIButton *buttonOfflineCache;

- (IBAction)onChangeMasterPassword:(id)sender;
- (IBAction)onButtonTouchId:(id)sender;
- (IBAction)onToggleOfflineCache:(id)sender;
- (IBAction)onExport:(id)sender;

@end
