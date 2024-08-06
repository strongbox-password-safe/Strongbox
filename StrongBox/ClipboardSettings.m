//
//  ClipboardSettings.m
//  Strongbox
//
//  Created by Strongbox on 19/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "ClipboardSettings.h"
#import "SelectItemTableViewController.h"
#import "Utils.h"
#import "AppPreferences.h"
#import "NSArray+Extensions.h"

@interface ClipboardSettings ()

@property (weak, nonatomic) IBOutlet UISwitch *clearClipboardEnabled;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellClearClipboardDelay;
@property (weak, nonatomic) IBOutlet UILabel *labelClearClipboardDelay;
@property (weak, nonatomic) IBOutlet UISwitch *switchAllowClipboardHandoff;

@end

@implementation ClipboardSettings

- (void)viewDidLoad {
    [super viewDidLoad];
 
    [self bindClearClipboard];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (cell == self.cellClearClipboardDelay) {
        [self promptForInteger:NSLocalizedString(@"prefs_vc_clear_clipboard_delay", @"Clear Clipboard Delay")
                       options:@[@30, @45, @60, @90, @120, @180]
             formatAsIntervals:YES
                  currentValue:AppPreferences.sharedInstance.clearClipboardAfterSeconds
                    completion:^(BOOL success, NSInteger selectedValue) {
                        if (success) {
                            AppPreferences.sharedInstance.clearClipboardAfterSeconds = selectedValue;
                        }
                        [self bindClearClipboard];
                    }];
    }

}

- (IBAction)onSwitchClearClipboardEnable:(id)sender {
    AppPreferences.sharedInstance.clearClipboardEnabled = self.clearClipboardEnabled.on;
    AppPreferences.sharedInstance.clipboardHandoff = self.switchAllowClipboardHandoff.on;
    
    [self bindClearClipboard];
}

- (void)bindClearClipboard {
    self.switchAllowClipboardHandoff.on = AppPreferences.sharedInstance.clipboardHandoff;

    NSInteger seconds = AppPreferences.sharedInstance.clearClipboardAfterSeconds;
    BOOL enabled = AppPreferences.sharedInstance.clearClipboardEnabled;
    
    self.clearClipboardEnabled.on = enabled;
    self.cellClearClipboardDelay.userInteractionEnabled = enabled;
    
    slog(@"clearClipboard: [%d, %ld]", enabled, (long)seconds);
    
    if(!enabled) {
        self.labelClearClipboardDelay.text = NSLocalizedString(@"prefs_vc_setting_disabled", @"Disabled");
    }
    else {
        self.labelClearClipboardDelay.text = [Utils formatTimeInterval:seconds];
    }
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [Utils formatTimeInterval:obj.integerValue] : obj.stringValue;
    }];
    vc.groupItems = @[items];
    
    NSInteger currentlySelectIndex = [options indexOfObject:@(currentValue)];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        
        NSInteger selectedValue = options[set.firstIndex].integerValue;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, selectedValue);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
