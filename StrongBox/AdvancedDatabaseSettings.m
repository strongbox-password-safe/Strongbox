//
//  SafeDetailsView.m
//  StrongBox
//
//  Created by Mark on 09/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AdvancedDatabaseSettings.h"
#import "IOsUtils.h"
#import "Alerts.h"
#import "Utils.h"
#import "KeyFileParser.h"
#import "PinsConfigurationController.h"
#import "AutoFillManager.h"
#import "ExportOptionsTableViewController.h"
#import "AttachmentsPoolViewController.h"
#import "NSArray+Extensions.h"
#import "BiometricsManager.h"
#import "FavIconBulkViewController.h"
#import "YubiManager.h"
#import "BookmarksHelper.h"
#import "AppPreferences.h"
#import "StatisticsPropertiesViewController.h"
#import "ScheduledExportConfigurationViewController.h"

@interface AdvancedDatabaseSettings ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellExport;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellViewAttachments;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBulkUpdateFavIcons;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellStats;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellScheduledExport;

@end

@implementation AdvancedDatabaseSettings

+ (instancetype)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"DatabaseOperations" bundle:nil];
    
    AdvancedDatabaseSettings* vc = [sb instantiateViewControllerWithIdentifier:@"AdvancedSettings"];
    
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    

    self.cellExport.imageView.image = [UIImage imageNamed:@"upload"];
    self.cellViewAttachments.imageView.image = [UIImage imageNamed:@"attach"];
    self.cellBulkUpdateFavIcons.imageView.image = [UIImage imageNamed:@"picture"];
    self.cellStats.imageView.image = [UIImage imageNamed:@"statistics"];

    self.cellExport.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    [self.cellExport.imageView setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];

    self.cellViewAttachments.imageView.image = [UIImage systemImageNamed:@"paperclip"];
    [self.cellViewAttachments.imageView setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];

    self.cellBulkUpdateFavIcons.imageView.image = [UIImage systemImageNamed:@"photo"];
    [self.cellBulkUpdateFavIcons.imageView setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
    
    self.cellStats.imageView.image = [UIImage systemImageNamed:@"number.circle"];
    [self.cellStats.imageView setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
    
    [self setupTableView];
}

- (void)setupTableView {
    BOOL formatUnsupported = self.viewModel.database.originalFormat == kPasswordSafe || self.viewModel.database.originalFormat == kKeePass1;
    BOOL featureDisabled = AppPreferences.sharedInstance.disableFavIconFeature;
    BOOL ro = self.viewModel.isReadOnly;
    
    [self cell:self.cellBulkUpdateFavIcons setHidden:formatUnsupported || featureDisabled || ro];
    [self cell:self.cellViewAttachments setHidden:self.viewModel.database.attachmentPool.count == 0];
    [self cell:self.cellExport setHidden:AppPreferences.sharedInstance.disableExport];
    [self cell:self.cellScheduledExport setHidden:AppPreferences.sharedInstance.disableExport];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    [self.navigationController setNavigationBarHidden:NO];
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToExportOptions"]) {
        UINavigationController* nav = segue.destinationViewController;
        ExportOptionsTableViewController* vc = (ExportOptionsTableViewController*)nav.topViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToAttachmentsPool"]) {
        AttachmentsPoolViewController* vc = (AttachmentsPoolViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToStatistics"]) {
        StatisticsPropertiesViewController* vc = (StatisticsPropertiesViewController*)segue.destinationViewController;
        vc.viewModel = self.viewModel;
    }
    else if ([segue.identifier isEqualToString:@"segueToScheduledExport"]) {
        ScheduledExportConfigurationViewController* vc = (ScheduledExportConfigurationViewController*)segue.destinationViewController;
        vc.model = sender;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if (cell == self.cellExport) {
        [self onExport];
    }
    else if (cell == self.cellViewAttachments) {
        [self viewAttachments];
    }
    else if (cell == self.cellBulkUpdateFavIcons) {
        [self onBulkUpdateFavIcons];
    }
    else if ( cell == self.cellScheduledExport ) {
        [self performSegueWithIdentifier:@"segueToScheduledExport" sender:self.viewModel];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)onBulkUpdateFavIcons {
    [FavIconBulkViewController presentModal:self
                                      nodes:self.viewModel.database.allActiveEntries
                                     onDone:^(BOOL go, NSDictionary<NSUUID *,UIImage *> * _Nullable selectedFavIcons) {
        [self dismissViewControllerAnimated:YES completion:nil];
        
        if(go && selectedFavIcons) {
            self.onDatabaseBulkIconUpdate(selectedFavIcons); 
        }
    }];
}

- (void)viewAttachments {
    [self performSegueWithIdentifier:@"segueToAttachmentsPool" sender:nil];
}

- (void)onExport {
    [self performSegueWithIdentifier:@"segueToExportOptions" sender:nil];
}

@end
