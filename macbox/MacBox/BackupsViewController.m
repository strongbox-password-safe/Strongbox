//
//  BackupsViewController.m
//  MacBox
//
//  Created by Strongbox on 07/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "BackupsViewController.h"
#import "BackupsManager.h"
#import "NSDate+Extensions.h"
#import "Utils.h"
#import "TableViewWithRightClickSelect.h"
#import "MacAlerts.h"
#import "Settings.h"

@interface BackupsViewController () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet TableViewWithRightClickSelect *tableView;
@property (weak) IBOutlet NSButton *checkboxTakeBackups;
@property (weak) IBOutlet NSTextField *textBoxMaximumKeepCount;
@property (weak) IBOutlet NSStepper *stepperMaximumKeepCount;
@property BOOL hasLoaded;
@property (strong) IBOutlet NSMenu *menuDummyRequiredToKeepAReference;
@property NSArray<BackupItem*> *items;

@end

@implementation BackupsViewController

- (void)cancel:(id)sender { 
    [self.presentingViewController dismissViewController:self];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewController:self];
}

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
    
    [self bindUi];
}

- (void)doInitialSetup {
    self.view.window.delegate = self;

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onExportBackup:);
}

- (void)bindUi {
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:self.databaseUuid];

    self.checkboxTakeBackups.enabled = Settings.sharedInstance.makeLocalRollingBackups;
    BOOL enabled = ( Settings.sharedInstance.makeLocalRollingBackups && database.makeBackups );
    
    self.checkboxTakeBackups.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.textBoxMaximumKeepCount.stringValue = @(database.maxBackupKeepCount).stringValue;
    self.stepperMaximumKeepCount.integerValue = database.maxBackupKeepCount;

    self.textBoxMaximumKeepCount.enabled = enabled;
    self.stepperMaximumKeepCount.enabled = enabled;
    
    [self refreshTableView];
}

- (void)refreshTableView {
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:self.databaseUuid];

    self.items = [BackupsManager.sharedInstance getAvailableBackups:database all:NO];

    [self.tableView reloadData];
}

- (IBAction)onTakeBackups:(id)sender {
    BOOL makeBackups = self.checkboxTakeBackups.state == NSControlStateValueOn;
    
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:self.databaseUuid];
    database.makeBackups = makeBackups;
    
    [self bindUi];
}

- (IBAction)onStepper:(id)sender {
    NSInteger maxBackupKeepCount = self.stepperMaximumKeepCount.integerValue;
    
    MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:self.databaseUuid];

    database.maxBackupKeepCount = maxBackupKeepCount;

    [self bindUi];
}

- (IBAction)onTextBoxMaximumKeepCount:(id)sender {
    self.stepperMaximumKeepCount.integerValue = self.textBoxMaximumKeepCount.integerValue;
    
    [self onStepper:nil];
}




- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView* ret = [self.tableView makeViewWithIdentifier:@"GenericBackupTableCellViewIdentifier" owner:nil];

    BackupItem *item = self.items[row];
    
    if ( [tableColumn.identifier isEqualToString:@"backupNumber"] ) {
        ret.textField.stringValue = @(row + 1).stringValue;
    }
    else if ( [tableColumn.identifier isEqualToString:@"dateModified"] ) {
        ret.textField.stringValue = item.modDate.friendlyDateTimeStringPrecise;
    }
    else if ( [tableColumn.identifier isEqualToString:@"backupTakenAt"] ) {
        ret.textField.stringValue = item.backupCreatedDate.friendlyDateTimeStringPrecise;
    }
    else if ( [tableColumn.identifier isEqualToString:@"size"] ) {
        ret.textField.stringValue = friendlyFileSizeString(item.fileSize.longLongValue);
    }

    return ret;
}




- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];

    if (theAction == @selector(onExportBackup:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }
    else if (theAction == @selector(onDeleteBackup:)) {
        if(self.tableView.selectedRow != -1) {
            return YES;
        }
    }

    return NO;
}

- (IBAction)onExportBackup:(id)sender {
    if(self.tableView.selectedRow != -1) {
        BackupItem *item = self.items[self.tableView.selectedRow];
        
        MacDatabasePreferences* database = [MacDatabasePreferences fromUuid:self.databaseUuid];

        NSString* suggestedFileName = [NSString stringWithFormat:@"Backup-of-%@", database.fileUrl.lastPathComponent];
                                
        NSSavePanel *savePanel = [NSSavePanel savePanel];
        savePanel.nameFieldStringValue = suggestedFileName;
        
        if ( [savePanel runModal] == NSModalResponseOK ) {
            NSError* error;
            if ( ![NSFileManager.defaultManager copyItemAtURL:item.url toURL:savePanel.URL error:&error] ) {
                [MacAlerts error:error window:self.view.window];
            }
        }
    }
}

- (IBAction)onDeleteBackup:(id)sender {
    if(self.tableView.selectedRow != -1) {
        BackupItem *item = self.items[self.tableView.selectedRow];
        
        [MacAlerts yesNo:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
         informativeText:NSLocalizedString(@"backup_vc_are_you_sure_remove", @"Are you sure you want to remove this backup?")
                  window:self.view.window
              completion:^(BOOL yesNo) {
            if ( yesNo ) {
                [BackupsManager.sharedInstance deleteBackup:item];
                [self refreshTableView];
            }
        }];
    }
}

@end
