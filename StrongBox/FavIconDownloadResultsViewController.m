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
    
    NSMutableArray<Node*>* success = @[].mutableCopy;
    NSMutableArray<Node*>* fail = @[].mutableCopy;
    
    for (NSUUID* uuid in self.validNodes) {
        NSArray<NodeIcon*>* images = [self getSortedImagesForNode:uuid];
        
        if(images == nil) {
            continue; 
        }
        else if (images.count == 0) {
            Node* node = [self.model getItemById:uuid];
            if ( node == nil ) { 
                node = [self.nodes firstOrDefault:^BOOL(Node * _Nonnull obj) {
                    return [obj.uuid isEqual:uuid];
                }];
            }

            if (!node) {
                continue;
            }

            [fail addObject:node];
        }
        else {
            Node* node = [self.model getItemById:uuid];
            if ( node == nil ) {
                node = [self.nodes firstOrDefault:^BOOL(Node * _Nonnull obj) {
                    return [obj.uuid isEqual:uuid];
                }];
            }

            if (!node) {
                continue;
            }

            [success addObject:node];
            
            [self autoSelectBestImageIndex:uuid];
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];
    Node* node = indexPath.section == 0 ? self.successful[indexPath.row] : self.failed[indexPath.row];
    BOOL failed = indexPath.section != 0;

    NSString* subtitle;
    UIImage* img;
    NodeIcon* icon;
    
    if ( failed ) {
        img = [UIImage systemImageNamed:@"exclamationmark.triangle"];
        subtitle = NSLocalizedString(@"favicon_results_no_icons_found", @"No FavIcons Found");
    }
    else {
        icon = [self getSelectedImageForNode:node.uuid];
        NSUInteger resultCount = self.nodeImagesMap[node.uuid].count;

        if ( icon ) {
            if( icon.customIconHeight != icon.customIconWidth && MIN(icon.customIconWidth, icon.customIconHeight) > 512 ) {
                slog(@"🔴 Down scaling icon...");
                img = scaleImage(icon.customIcon, CGSizeMake(128, 128));
            }
            else {
                img = icon.customIcon;
            }
            
            subtitle = [NSString stringWithFormat:@"%lu Icons Found (%dx%d selected) %@",
                        (unsigned long)resultCount,
                        (int)icon.customIconWidth,
                        (int)icon.customIconHeight,
                        friendlyFileSizeString(icon.estimatedStorageBytes)];
        }
        else {
            img = [UIImage systemImageNamed:@"xmark.circle"];
            subtitle = [NSString stringWithFormat:@"%lu Icons Found (None Selected)", (unsigned long)resultCount];
        }
    }
    
    [cell setRecord:node.title
           subtitle:subtitle
               icon:img
      groupLocation:@""
              flags:@[]
     flagTintColors:@{}
            expired:NO
           otpToken:nil
           hideIcon:NO
              audit:@""
     imageTintColor:!failed ? nil : UIColor.systemOrangeColor];
    
    cell.accessoryType = indexPath.section == 0 ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return cell;
}



- (NSArray<NodeIcon*>*)getSortedImagesForNode:(NSUUID*)uuid {
    NSArray<NodeIcon*>* icons = self.nodeImagesMap[uuid];
    
    return [FavIconManager.sharedInstance getSortedImages:icons
                                                  options:AppPreferences.sharedInstance.favIconDownloadOptions];
}

- (void)autoSelectBestImageIndex:(NSUUID*)uuid {
    NSArray<NodeIcon*>* sorted = [self getSortedImagesForNode:uuid];
    
    NodeIcon* best = [FavIconManager.sharedInstance getIdealImage:sorted
                                                          options:AppPreferences.sharedInstance.favIconDownloadOptions];

    if ( best != nil ) {
        NSUInteger bestIndex = [sorted indexOfObject:best];
        self.nodeSelected[uuid] = @(bestIndex);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {


    if(indexPath.section == 0) {


            [self performSegueWithIdentifier:@"segueToViewMultipleFavIcons" sender:indexPath];

    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToViewMultipleFavIcons"]) {
        NSIndexPath* indexPath = (NSIndexPath*)sender;
        Node* node = self.successful[indexPath.row];
        
        NSArray<NodeIcon*>* images = [self getSortedImagesForNode:node.uuid];
        
        FavIconSelectFromMultipleFavIconsTableViewController* vc = (FavIconSelectFromMultipleFavIconsTableViewController*)segue.destinationViewController;
        
        vc.node = node;
        vc.images = images;
        vc.selectedIdx = self.nodeSelected[node.uuid];

        vc.onChangedSelection = ^(NSNumber * _Nonnull idx) {
            self.nodeSelected[node.uuid] = idx;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        };
    }
}

- (IBAction)onCancel:(id)sender {    
    self.onDone(NO, nil);
}

- (NodeIcon*)getSelectedImageForNode:(NSUUID*)uuid {
    NSNumber* index = self.nodeSelected[uuid];
    
    NSArray<NodeIcon*>* images = [self getSortedImagesForNode:uuid];
    
    if (images != nil && index != nil && index.intValue < images.count && index.intValue >= 0) {
        return images[index.intValue];
    }
     
    return nil;
}

- (IBAction)onDone:(id)sender {
    NSMutableDictionary<NSUUID*, NodeIcon*> *selected = @{}.mutableCopy;

    for (Node* node in self.successful) {
        NodeIcon* image = [self getSelectedImageForNode:node.uuid];
        if ( image ) {
            selected[node.uuid] = image;
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
