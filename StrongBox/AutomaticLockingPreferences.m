//
//  AutomaticLockingPreferences.m
//  Strongbox
//
//  Created by Strongbox on 10/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AutomaticLockingPreferences.h"
#import "Utils.h"
#import "DatabasePreferences.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"

@interface AutomaticLockingPreferences ()

@property (weak, nonatomic) IBOutlet UILabel *labelDatabaseAutoLockDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchDatabaseAutoLockEnabled;
@property (weak, nonatomic) IBOutlet UISwitch *switchLockOnDeviceLock;
@property (weak, nonatomic) IBOutlet UISwitch *switchLockDuringEditing;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDatabaseAutoLockDelay;

@end

@implementation AutomaticLockingPreferences

+ (instancetype)fromStoryboardWithModel:(Model*)model {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"DatabaseOperations" bundle:nil];
    
    AutomaticLockingPreferences* vc = [sb instantiateViewControllerWithIdentifier:@"AutomaticLocking"];
    
    vc.viewModel = model;
    
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self bindUi];
}

- (void)bindUi {
    NSNumber* seconds = self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds : @(-1);
    
    if(seconds.integerValue == -1) {
        self.switchDatabaseAutoLockEnabled.on = NO;
        self.labelDatabaseAutoLockDelay.text = NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = NO;
    }
    else {
        self.switchDatabaseAutoLockEnabled.on = YES;
        self.labelDatabaseAutoLockDelay.text = [Utils formatTimeInterval:seconds.integerValue];
        self.cellDatabaseAutoLockDelay.userInteractionEnabled = YES;
    }

    self.switchLockOnDeviceLock.on = self.viewModel.metadata.autoLockOnDeviceLock;
    self.switchLockDuringEditing.on = self.viewModel.metadata.lockEvenIfEditing;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellDatabaseAutoLockDelay) {
        [self promptForAutoLockTimeout];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptForAutoLockTimeout {
    [self promptForInteger:NSLocalizedString(@"prefs_vc_auto_lock_database_delay", @"Auto Lock Delay")
                   options:@[@0, @30, @60, @120, @180, @300, @600]
         formatAsIntervals:YES
              currentValue:self.viewModel.metadata.autoLockTimeoutSeconds ? self.viewModel.metadata.autoLockTimeoutSeconds.integerValue : 60
                completion:^(BOOL success, NSInteger selectedValue) {
                    if (success) {
                        self.viewModel.metadata.autoLockTimeoutSeconds = @(selectedValue);
                    }
                    [self bindUi];
                }];
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];

    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];

    [self promptForChoice:title options:items currentlySelectIndex:currentlySelectIndex completion:^(BOOL success, NSInteger selectedIndex) {
        completion(success, success ? options[selectedIndex].integerValue : -1);
    }];
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
    currentlySelectIndex:(NSInteger)currentlySelectIndex
              completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;

    vc.groupItems = @[items];
    
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onSwitchDatabaseAutoLockEnabled:(id)sender {
    self.viewModel.metadata.autoLockTimeoutSeconds = self.switchDatabaseAutoLockEnabled.on ? @(60) : @(-1);
    [self bindUi];
}

- (IBAction)onSwitchLockOnDeviceLock:(id)sender {
    self.viewModel.metadata.autoLockOnDeviceLock = self.switchLockOnDeviceLock.on;
    [self bindUi];
}

- (IBAction)onSwitchLockEvenIfEditing:(id)sender {
    self.viewModel.metadata.lockEvenIfEditing = self.switchLockDuringEditing.on;
    [self bindUi];
}

- (IBAction)oDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
