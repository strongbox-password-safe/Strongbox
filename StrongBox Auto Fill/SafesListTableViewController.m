//
//  SafesListTableViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafesListTableViewController.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "SafeStorageProviderFactory.h"
#import "Settings.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "CredentialProviderViewController.h"
#import "OpenSafeSequenceHelper.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "PickCredentialsTableViewController.h"

@interface SafesListTableViewController ()

@property NSArray<SafeMetaData*> *safes;

@end

@implementation SafesListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
 
    [self refreshSafes];

    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.tableView.rowHeight = 65.0f;
    
    [SVProgressHUD setViewForExtension:self.view];
}

- (void)refreshSafes {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        self.safes = SafesList.sharedInstance.snapshot;
        [self.tableView reloadData];
        
        SafeMetaData* primary = [[self getInitialViewController] getPrimarySafe];

        if(primary && [[self getInitialViewController] autoFillIsPossibleWithSafe:primary]) {
            [self.barButtonShowQuickView setEnabled:YES];
            [self.barButtonShowQuickView setTintColor:nil];
        }
        else {
            [self.barButtonShowQuickView setEnabled:NO];
            [self.barButtonShowQuickView setTintColor: [UIColor clearColor]];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:NO];
    self.navigationController.toolbar.hidden = NO;
    self.navigationController.toolbarHidden = NO;
    
    showWelcomeMessageIfAppropriate(self);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
   
    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (IBAction)onCancel:(id)sender {
    [[self getInitialViewController] cancel:nil];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapView:(UIView *)view {
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button
{
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIImage imageNamed:@"Strongbox-180x180-greyed"];
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    NSDictionary *attributes = @{
                                 NSFontAttributeName: [UIFont boldSystemFontOfSize:21.0f],
                                 NSForegroundColorAttributeName: [UIColor blueColor]
                                 };
    
    return [[NSAttributedString alloc] initWithString:@"Got It, Take Me Back" attributes:attributes];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"You Have No Strongbox Databases :(";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"To use Strongbox for Password Autofill you need to add a database. You can do this in the Strongbox App.";
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.safes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseIdentifier" forIndexPath:indexPath];
    
    SafeMetaData *safe = [self.safes objectAtIndex:indexPath.row];
    
    cell.textLabel.text = safe.nickName;
    cell.detailTextLabel.text = safe.fileName;
    cell.imageView.userInteractionEnabled = YES;
    cell.userInteractionEnabled = YES;
    cell.textLabel.enabled = YES;
    cell.detailTextLabel.enabled = YES;
    
    if([[self getInitialViewController] autoFillIsPossibleWithSafe:safe]) {
        if(![[self getInitialViewController] isLiveAutoFillProvider:safe.storageProvider]) {
            NSDate* mod = [LocalDeviceStorageProvider.sharedInstance getAutoFillCacheModificationDate:safe];
            
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            df.timeStyle = NSDateFormatterShortStyle;
            df.dateStyle = NSDateFormatterShortStyle;
            df.doesRelativeDateFormatting = YES;
            df.locale = NSLocale.currentLocale;
            
            NSString *modDateStr = [df stringFromDate:mod];
            
            cell.detailTextLabel.text = [NSString stringWithFormat:@"[Cached %@]", modDateStr];
        }
        
        // FUTURE: When we get OneDrive working use the alternate branch below... :(
        if(safe.storageProvider == kOneDrive) {
            UIImage* img = [UIImage imageNamed:@"one-drive-icon-only-32x32"];
            cell.imageView.image = img;
        }
        else {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:safe.storageProvider];
            NSString *icon = provider.icon;
            UIImage* img = [UIImage imageNamed:icon];
            cell.imageView.image = img;
        }
    }
    else {
        cell.imageView.image = [UIImage imageNamed:@"cancel_32"];
        cell.imageView.userInteractionEnabled = NO;
        cell.userInteractionEnabled = NO;
        cell.textLabel.enabled = NO;
        cell.detailTextLabel.enabled = NO;
        
        if(safe.autoFillCacheEnabled) {
            cell.detailTextLabel.text = @"[No Auto Fill Cache File Yet]";
        }
        else {
            cell.detailTextLabel.text = @"[Auto Fill Cache Disabled]";
        }
    }
    
    return cell;
}

- (CredentialProviderViewController *)getInitialViewController {
    return self.rootViewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeMetaData* safe = [self.safes objectAtIndex:indexPath.row];

    BOOL useAutoFillCache = ![[self getInitialViewController] isLiveAutoFillProvider:safe.storageProvider];
    
    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                        safe:safe
                                          openAutoFillCache:useAutoFillCache
                                          canConvenienceEnrol:NO
                                                 completion:^(Model * _Nonnull model) {
                                                          if(model) {
                                                              [self performSegueWithIdentifier:@"toPickCredentialsFromSafes" sender:model];
                                                          }
                                                          [self refreshSafes]; // Duress may have removed one
                                                      }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toPickCredentialsFromSafes"]) {
        PickCredentialsTableViewController *vc = segue.destinationViewController;
        vc.model = (Model *)sender;
        vc.rootViewController = self.rootViewController;
    }
}

- (IBAction)onShowQuickLaunchView:(id)sender {
    Settings.sharedInstance.useQuickLaunchAsRootView = YES;
    
    [[self getInitialViewController] showQuickLaunchView];
}
    

@end
