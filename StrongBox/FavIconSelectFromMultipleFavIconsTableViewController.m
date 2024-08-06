//
//  FavIconSelectFromMultipleFavIconsTableViewController.m
//  Strongbox
//
//  Created by Mark on 30/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconSelectFromMultipleFavIconsTableViewController.h"
#import "Utils.h"
#import "BrowseItemCell.h"
#import "AppPreferences.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";

@interface FavIconSelectFromMultipleFavIconsTableViewController ()

@end

@implementation FavIconSelectFromMultipleFavIconsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
    
    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];

    UIImage* img;
    NodeIcon* icon = self.images[indexPath.row];
    if( icon.customIconHeight != icon.customIconWidth && MIN(icon.customIconWidth, icon.customIconHeight) > 512 ) {
        slog(@"🔴 Down scaling icon...");
        img = scaleImage(icon.customIcon, CGSizeMake(192, 192));
    }
    else {
        img = icon.customIcon;
    }
    
    BOOL largeIcon = icon.estimatedStorageBytes > AppPreferences.sharedInstance.favIconDownloadOptions.maxSize;
    
    NSString* subtitle = [NSString stringWithFormat:@"%@ (%dx%d) %@",
                          largeIcon ? @"⚠️ " : @"",
                          (int)icon.customIconWidth,
                          (int)icon.customIconHeight,
                          friendlyFileSizeString(icon.estimatedStorageBytes)];
    
    [cell setRecord:self.node.title
           subtitle:subtitle 
               icon:img
      groupLocation:@""
              flags:@[]
     flagTintColors:@{}
            expired:NO
           otpToken:nil
           hideIcon:NO
              audit:@""];

    cell.accessoryType = self.selectedIdx == nil ? UITableViewCellAccessoryNone : ((indexPath.row == self.selectedIdx.unsignedIntValue) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( self.selectedIdx == nil ) {
        self.selectedIdx = @(indexPath.row);
    }
    else {
        NSUInteger selectedIndex = self.selectedIdx.unsignedIntValue;
        
        if ( selectedIndex != indexPath.row ) {
            self.selectedIdx = @(indexPath.row);
            
        }
        else {
            self.selectedIdx = nil; 
        }
    }
    
    self.onChangedSelection(self.selectedIdx);
    
    [self.tableView reloadData];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
 
    [self.navigationController popViewControllerAnimated:YES];
}     

@end
