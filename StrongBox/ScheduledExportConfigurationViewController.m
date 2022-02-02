//
//  ScheduledExportConfigurationViewController.m
//  Strongbox
//
//  Created by Strongbox on 24/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ScheduledExportConfigurationViewController.h"
#import "DatabasePreferences.h"
#import "SelectItemTableViewController.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

@interface ScheduledExportConfigurationViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *switchEnabled;
@property (weak, nonatomic) IBOutlet UILabel *labelInterval;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellInterval;
@property (weak, nonatomic) IBOutlet UILabel *labelNextExport;
@property (weak, nonatomic) IBOutlet UILabel *labelLastExportMod;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellNextExport;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLastExportMod;

@end

@implementation ScheduledExportConfigurationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self bindUI];
}

- (void)bindUI {
    self.switchEnabled.on = self.model.metadata.scheduledExport;
    self.labelInterval.text = [self formatInterval:self.model.metadata.scheduleExportIntervalDays];
    self.labelNextExport.text = self.model.metadata.nextScheduledExport.friendlyDateString;
    self.labelLastExportMod.text = self.model.metadata.lastScheduledExportModDate ? self.model.metadata.lastScheduledExportModDate.friendlyDateTimeString : @"";
    
    [self cell:self.cellInterval setHidden:!self.model.metadata.scheduledExport];
    [self cell:self.cellNextExport setHidden:!self.model.metadata.scheduledExport];
    [self cell:self.cellLastExportMod setHidden:!self.model.metadata.scheduledExport || self.model.metadata.lastScheduledExportModDate == nil];

    [self reloadDataAnimated:YES];
}

- (IBAction)onToggleEnabled:(id)sender {
    self.model.metadata.scheduledExport = self.switchEnabled.on;
    self.model.metadata.nextScheduledExport = [NSDate.date dateByAddingTimeInterval:self.model.metadata.scheduleExportIntervalDays * 24 * 60 * 60];

    [self bindUI];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];

    if (cell == self.cellInterval) {
        [self promptForInterval];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)promptForInterval {
    [self promptForInteger:NSLocalizedString(@"prefs_vc_scheduled_export_interval", @"Scheduled Export Interval")
                   options:@[@1, @5, @7, @14, @21, @28, @56, @84]
         formatAsIntervals:YES
              currentValue:self.model.metadata.scheduleExportIntervalDays
                completion:^(BOOL success, NSInteger selectedValue) {
                    if (success) {
                        self.model.metadata.scheduleExportIntervalDays = selectedValue;
                        self.model.metadata.nextScheduledExport = [NSDate.date dateByAddingTimeInterval:self.model.metadata.scheduleExportIntervalDays * 24 * 60 * 60];
                    }
                    [self bindUI];
                }];
}

- (void)promptForInteger:(NSString*)title
                 options:(NSArray<NSNumber*>*)options
       formatAsIntervals:(BOOL)formatAsIntervals
            currentValue:(NSInteger)currentValue
              completion:(void(^)(BOOL success, NSInteger selectedValue))completion {
    
    NSArray<NSString*>* items = [options map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return formatAsIntervals ? [self formatInterval:obj.integerValue] : obj.stringValue;
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

- (NSString*)formatInterval:(NSUInteger)interval {
    NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];

    fmt.allowedUnits = (NSCalendarUnitDay | NSCalendarUnitWeekOfMonth);
    fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    
    return [fmt stringFromTimeInterval:interval * 24 * 60 * 60];
}

@end
