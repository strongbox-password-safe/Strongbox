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
#import "InitialTabViewController.h"
#import "SafeStorageProviderFactory.h"
#import "Settings.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "CredentialProviderViewController.h"
#import "OpenSafeSequenceHelper.h"

@interface SafesListTableViewController ()

@property NSArray<SafeMetaData*> *safes;

@end

@implementation SafesListTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.safes = SafesList.sharedInstance.snapshot;

    if([[self getInitialViewController] getPrimarySafe]) {
        [self.barButtonShowQuickView setEnabled:YES];
        [self.barButtonShowQuickView setTintColor:nil];
    }
    else {
        [self.barButtonShowQuickView setEnabled:NO];
        [self.barButtonShowQuickView setTintColor: [UIColor clearColor]];
    }
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.tableView.rowHeight = 65.0f;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
   
    if (self.tableView.contentOffset.y < 0 && self.tableView.emptyDataSetVisible) {
        self.tableView.contentOffset = CGPointZero;
    }
}

- (IBAction)onCancel:(id)sender {
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
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
    NSString *text = @"You Have No Strongbox Safes :(";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"To use Strongbox for Password Autofill you need to add a safe. You can do this in the Strongbox App.";
    
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
    
    if(![[self getInitialViewController] isUnsupportedAutoFillProvider:safe.storageProvider]) {
        id<SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:safe.storageProvider];
        
        NSString *icon = provider.icon;
        cell.imageView.image = [UIImage imageNamed:icon];
    }
    else {
        cell.imageView.image = [UIImage imageNamed:@"cancel_32"];
        cell.imageView.userInteractionEnabled = NO;
        cell.textLabel.text = [NSString stringWithFormat:@"%@ [Autofill Not Supported]", safe.nickName];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ [Autofill Not Supported]", safe.fileName];
        cell.userInteractionEnabled = NO;
        cell.textLabel.enabled = NO;
        cell.detailTextLabel.enabled = NO;
    }
    
    return cell;
}

- (InitialTabViewController *)getInitialViewController {
    InitialTabViewController *ivc = (InitialTabViewController*)self.navigationController.parentViewController;
    return ivc;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SafeMetaData* safe = [self.safes objectAtIndex:indexPath.row];

    [OpenSafeSequenceHelper.sharedInstance beginOpenSafeSequence:self
                                                            safe:safe
                               askAboutTouchIdEnrolIfAppropriate:NO
                                                      completion:^(Model * _Nonnull model) {
                                                          if(model) {
                                                              [self performSegueWithIdentifier:@"segueFromListToPickCredentials" sender:model];
                                                          }
                                                      }];

}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueFromListToPickCredentials"]) {
        CredentialProviderViewController *vc = segue.destinationViewController;
        vc.viewModel = (Model *)sender;
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.

 //segueFromListToPickCredentials
 }
*/

- (IBAction)onShowQuickLaunchView:(id)sender {
    Settings.sharedInstance.useQuickLaunchAsRootView = YES;
    
    [[self getInitialViewController] showQuickLaunchView];
}

@end
