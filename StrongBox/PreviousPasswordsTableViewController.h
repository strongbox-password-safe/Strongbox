//
//  PreviousPasswordsTableViewController.h
//  StrongBox
//
//  Created by Mark on 29/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PasswordHistory.h"

@interface PreviousPasswordsTableViewController : UITableViewController

@property (nonatomic, retain) PasswordHistory *model;

@end
