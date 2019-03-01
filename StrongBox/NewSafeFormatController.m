//
//  NewSafeFormatController.m
//  Strongbox-iOS
//
//  Created by Mark on 06/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "NewSafeFormatController.h"
#import "SelectStorageProviderController.h"

@interface NewSafeFormatController ()

@property DatabaseFormat selectedFormat;

@end

@implementation NewSafeFormatController

- (void)viewDidLoad {
    self.tableView.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.hidden = YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
            self.selectedFormat = kKeePass;
            break;
        case 1:
            self.selectedFormat = kKeePass4;
            break;
        case 2:
            self.selectedFormat = kPasswordSafe;
            break;
        case 3:
            self.selectedFormat = kKeePass1;
            break;
        default:
            NSLog(@"WARN: Unknown Index Path!!");
            break;
    }
    
    NSLog(@"Selected: %d", self.selectedFormat);
    
    [self performSegueWithIdentifier:@"segueToSelectStorage" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SelectStorageProviderController *vc = segue.destinationViewController;
    vc.existing = NO;
    vc.format = self.selectedFormat;
}

@end
