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
#import "CacheManager.h"
#import "NSArray+Extensions.h"
#import "DatabaseCell.h"
#import "Utils.h"
#import "LocalDeviceStorageProvider.h"

@interface SafesListTableViewController ()

@property NSArray<SafeMetaData*> *safes;

@end

@implementation SafesListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
 
    [self refreshSafes];

    [self.tableView registerNib:[UINib nibWithNibName:kDatabaseCell bundle:nil] forCellReuseIdentifier:kDatabaseCell];
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.separatorStyle = Settings.sharedInstance.showDatabasesSeparator ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;

    [SVProgressHUD setViewForExtension:self.view];
    
    if(Settings.sharedInstance.quickLaunchUuid) {
        SafeMetaData* database = [self.safes firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
            return [obj.uuid isEqualToString:Settings.sharedInstance.quickLaunchUuid];
        }];
     
        if(database && [[self getInitialViewController] autoFillIsPossibleWithSafe:database]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openDatabase:database];
            });
        }
    }
}

- (void)refreshSafes {
    self.safes = SafesList.sharedInstance.snapshot;

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.tableView reloadData];
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
    return [UIImage imageNamed:@"AppIcon-2019-bw-180"];
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

- (NSString*)getAutoFillCacheDate:(SafeMetaData*)safe {
    NSDate* mod = [CacheManager.sharedInstance getAutoFillCacheModificationDate:safe];
    return mod ? [NSString stringWithFormat:@"Cached: %@", friendlyDateStringVeryShort(mod)] : @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatabaseCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatabaseCell forIndexPath:indexPath];
    SafeMetaData *safe = [self.safes objectAtIndex:indexPath.row];
    
    BOOL autoFillPossible = [[self getInitialViewController] autoFillIsPossibleWithSafe:safe];
    [self populateDatabaseCell:cell database:safe disabled:!autoFillPossible];
    
    return cell;
}

- (UIImage*)getStatusImage:(SafeMetaData*)database {
    if(database.hasUnresolvedConflicts) {
        return [UIImage imageNamed:@"error"];
    }
    else if([Settings.sharedInstance.quickLaunchUuid isEqualToString:database.uuid]) {
        return [UIImage imageNamed:@"rocket"];
    }
    else if(database.readOnly) {
        return [UIImage imageNamed:@"glasses"];
    }
    
    return nil;
}

- (void)populateDatabaseCell:(DatabaseCell*)cell database:(SafeMetaData*)database disabled:(BOOL)disabled {
    UIImage* statusImage = Settings.sharedInstance.showDatabaseStatusIcon ? [self getStatusImage:database] : nil;
    
    NSString* topSubtitle = [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellTopSubtitle];
    NSString* subtitle1 = [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellSubtitle1];
    NSString* subtitle2 = @""; // [self getDatabaseCellSubtitleField:database field:Settings.sharedInstance.databaseCellSubtitle2];
    
    
    UIImage* databaseIcon = nil;
    if(Settings.sharedInstance.showDatabaseIcon) {
        if(database.storageProvider == kOneDrive) {
            databaseIcon = [UIImage imageNamed:@"one-drive-icon-only-32x32"];
        }
        else {
            id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
            databaseIcon = [UIImage imageNamed:provider.icon];
        }
    }
    
    // If we can't do live show auto fill cache date in subtitle 2
    
    if(disabled) {
        databaseIcon = Settings.sharedInstance.showDatabaseIcon ? [UIImage imageNamed:@"cancel_32"] : nil;
        subtitle2 = database.autoFillEnabled ? @"[No Auto Fill Cache File Yet]" : @"[Auto Fill Disabled]";
    }
    else {
        if(![[self getInitialViewController] liveAutoFillIsPossibleWithSafe:database]) {
            subtitle2 = [self getAutoFillCacheDate:database];
        }
    }
    
    [cell set:database.nickName
  topSubtitle:topSubtitle
    subtitle1:subtitle1
    subtitle2:subtitle2
 providerIcon:databaseIcon
  statusImage:statusImage
     disabled:disabled];
}


- (NSString*)getDatabaseCellSubtitleField:(SafeMetaData*)database field:(DatabaseCellSubtitleField)field {
    switch (field) {
        case kDatabaseCellSubtitleFieldNone:
            return nil;
            break;
        case kDatabaseCellSubtitleFieldFileName:
            return database.fileName;
            break;
        case kDatabaseCellSubtitleFieldLastCachedDate:
            return [self getAutoFillCacheDate:database];
            break;
        case kDatabaseCellSubtitleFieldStorage:
            return [self getStorageString:database];
            break;
        default:
            return @"<Unknown Field>";
            break;
    }
}

- (NSString*)getStorageString:(SafeMetaData*)database {
    NSString* providerString;
    if(database.storageProvider == kOneDrive) {
        providerString = @"OneDrive";
    }
    else {
        id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:database.storageProvider];
        providerString = provider.displayName;
        if(database.storageProvider == kLocalDevice) {
            providerString = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:database] ? @"Local" : @"Local (Documents)";
        }
        
    }
    
    return providerString;
}

- (CredentialProviderViewController *)getInitialViewController {
    return self.rootViewController;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeMetaData* safe = [self.safes objectAtIndex:indexPath.row];
    
    [self openDatabase:safe];
}

- (void)openDatabase:(SafeMetaData*)safe {
    BOOL useAutoFillCache = ![[self getInitialViewController] liveAutoFillIsPossibleWithSafe:safe];
    
    [OpenSafeSequenceHelper beginSequenceWithViewController:self
                                                       safe:safe
                                          openAutoFillCache:useAutoFillCache
                                        canConvenienceEnrol:NO
                                             isAutoFillOpen:YES
                                     manualOpenOfflineCache:NO
                                biometricAuthenticationDone:NO
                                                 completion:^(Model * _Nullable model, NSError * _Nullable error) {
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

@end
