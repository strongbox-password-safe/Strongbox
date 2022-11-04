//
//  FavIconDownloadResultsViewController.m
//  Strongbox
//
//  Created by Mark on 27/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconDownloadResultsViewController.h"
#import "Utils.h"
#import "NSArray+Extensions.h"
#import "FavIconSelectFromMultipleFavIconsTableViewController.h"
#import "FavIconManager.h"
#import "Alerts.h"
#import "AppPreferences.h"
#import "NSString+Extensions.h"
#import "BrowseItemCell.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";

@interface FavIconDownloadResultsViewController ()

@property NSMutableDictionary<NSUUID*, NSNumber*> *nodeSelected;

@property BOOL hasFailures;

@property NSArray<Node*> *successful;
@property NSArray<Node*> *failed;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneButton;

@end

@implementation FavIconDownloadResultsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableFooterView = UIView.new;
    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];

    self.nodeSelected = @{}.mutableCopy;
    
    NSMutableArray* success = @[].mutableCopy;
    NSMutableArray* fail = @[].mutableCopy;
    for (Node* node in self.nodes) {
        NSArray<UIImage*>* images = [self getImagesForNode:node];
        
        if(images == nil) {
            continue; 
        }
        else if (images.count == 0) {
            [fail addObject:node];
        }
        else {
            [success addObject:node];
            self.nodeSelected[node.uuid] = [self selectBestImageIndex:images];
        }
    }
    
    self.successful = [success sortedArrayUsingComparator:finderStyleNodeComparator];
    self.failed = [fail sortedArrayUsingComparator:finderStyleNodeComparator];
    
    self.title = AppPreferences.sharedInstance.isPro ? NSLocalizedString(@"favicon_results_title", @"FavIcon Results") : NSLocalizedString(@"favicon_results_title_pro_only", @"FavIcon Results (Pro Only)");
                      
    [self refresh];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.successful.count : self.failed.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return section == 0 || self.failed.count == 0 ? 0.0001f : [super tableView:tableView heightForHeaderInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 && self.failed.count > 0 ? NSLocalizedString(@"generic_failed", @"Failed") : [super tableView:tableView titleForHeaderInSection:section];
}

- (NSArray<UIImage*>*)getImagesForNode:(Node*)node {
    NSArray<UIImage*> *ret = self.results[self.singleNodeUrlOverride ? self.singleNodeUrlOverride : node.fields.url.urlExtendedParse];
    
    return [ret sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UIImage* imageA = obj1;
        UIImage* imageB = obj2;
        
        return imageA.size.width == imageB.size.width ? NSOrderedSame : ( imageA.size.width > imageB.size.width ? NSOrderedAscending : NSOrderedDescending);
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {


    Node* node = indexPath.section == 0 ? self.successful[indexPath.row] : self.failed[indexPath.row];


    
    UIImage* image = nil;
    
    NSArray<UIImage*>* images = [self getImagesForNode:node];
    NSNumber* selectedIndex = self.nodeSelected[node.uuid];
    
    image = (images && selectedIndex != nil && selectedIndex.intValue < images.count && selectedIndex.intValue >= 0) ? images[selectedIndex.intValue] : nil;







    











    





  


    
    
    
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

    
    
    image = image ? image : [UIImage imageNamed:@"error"];
    
    if( image.size.height != image.size.width && MIN(image.size.width, image.size.height) > 512 ) {
        NSLog(@"🔴 Down scaling icon...");
        image = scaleImage(image, CGSizeMake(128, 128));
    }
    
    
    
    NSString* subtitle;
    if (images.count > 1) {
        subtitle = [NSString stringWithFormat:NSLocalizedString(@"favicon_results_n_icons_found_with_xy_resolution_fmt", @"%lu Icons Found (%dx%d selected)"),
                                     (unsigned long)images.count,
                                     (int)image.size.width,
                                     (int)image.size.height];
    }
    else {
        subtitle = image ? [NSString stringWithFormat:NSLocalizedString(@"favicon_results_one_icon_found_with_xy_resolution_fmt", @"%dx%d selected"),
                                             (int)image.size.width,
                                             (int)image.size.height] : NSLocalizedString(@"favicon_results_no_icons_found", @"No FavIcons Found");
    }

    
    

    image = image ? image : [UIImage imageNamed:@"error"];

    [cell setRecord:node.title
           subtitle:subtitle
               icon:image
      groupLocation:@""
              flags:@[]
     flagTintColors:@{}
            expired:NO
           otpToken:nil
           hideIcon:NO
              audit:@""];
    
    
    if(indexPath.section == 0) {
        cell.accessoryType = images.count > 1 ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    }
    else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    cell.detailTextLabel.textColor = image ? nil : UIColor.systemRedColor;

    return cell;
}

- (NSNumber*)selectBestImageIndex:(NSArray<UIImage*>*)images {
    UIImage* image = [FavIconManager.sharedInstance selectBest:images];
    return @([images indexOfObject:image]);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* node = indexPath.section == 0 ? self.successful[indexPath.row] : self.failed[indexPath.row];

    if(indexPath.section == 0) {
        NSArray<UIImage*>* images = [self getImagesForNode:node];
        if(images.count > 1) {
            [self performSegueWithIdentifier:@"segueToViewMultipleFavIcons" sender:indexPath];
        }
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToViewMultipleFavIcons"]) {
        NSIndexPath* indexPath = (NSIndexPath*)sender;
        Node* node = self.successful[indexPath.row];
        
        NSArray<UIImage*>* images = [self getImagesForNode:node];
        
        FavIconSelectFromMultipleFavIconsTableViewController* vc = (FavIconSelectFromMultipleFavIconsTableViewController*)segue.destinationViewController;
        
        vc.node = node;
        vc.images = images;
        vc.selectedIndex = self.nodeSelected[node.uuid].intValue;
        vc.onChangedSelection = ^(NSUInteger index) {
            self.nodeSelected[node.uuid] = @(index);
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        };
    }
}

- (IBAction)onCancel:(id)sender {    
    self.onDone(NO, nil);
}

- (IBAction)onDone:(id)sender {
    NSMutableDictionary<NSUUID*, UIImage*> *selected = @{}.mutableCopy;

    for (Node* obj in self.successful) {
        NSNumber* index = self.nodeSelected[obj.uuid];
        
        NSArray<UIImage*>* images = [self getImagesForNode:obj];
        
        if (images != nil && index != nil && index.intValue < images.count && index.intValue >= 0) {
            selected[obj.uuid] = images[index.intValue];
        }
    }
    
    self.onDone(YES, selected);
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                                                            title:NSLocalizedString(@"safes_vc_slide_left_remove_database_action", @"Remove this database table action")
                                                                          handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [Alerts yesNo:self
                title:NSLocalizedString(@"generic_are_you_sure", @"Are you sure?")
              message:NSLocalizedString(@"favicon_results_are_you_sure_remove_result_message", @"Are you sure you want to remove this FavIcon result?")
               action:^(BOOL response) {
            if(response) {
                NSMutableArray* mut = self.successful.mutableCopy;
                [mut removeObjectAtIndex:indexPath.row];
                
                self.successful = mut.copy;
                
                [self refresh];
            }
        }];
    }];

    return indexPath.section == 0 ? @[removeAction] : @[];
}

- (void)refresh {
    self.doneButton.enabled = self.successful.count > 0 && AppPreferences.sharedInstance.isPro;
    [self.tableView reloadData];
}

@end
