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

    UIImage* image = self.images[indexPath.row];
    if( image.size.height != image.size.width && MIN(image.size.width, image.size.height) > 512 ) {
        NSLog(@"🔴 Down scaling icon...");
        image = scaleImage(image, CGSizeMake(192, 192));
    }

    [cell setRecord:self.node.title
           subtitle:[NSString stringWithFormat:@"%dx%d", (int)image.size.width, (int)image.size.height]
               icon:image
      groupLocation:@""
              flags:@[]
     flagTintColors:@{}
            expired:NO
           otpToken:nil
           hideIcon:NO
              audit:@""];

    cell.accessoryType = indexPath.row == self.selectedIndex ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.selectedIndex = indexPath.row;
    
    [self.tableView reloadData];
    
    self.onChangedSelection(self.selectedIndex);
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
 
    [self.navigationController popViewControllerAnimated:YES];
}     

@end
