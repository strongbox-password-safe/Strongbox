//
//  FavIconSelectFromMultipleFavIconsTableViewController.m
//  Strongbox
//
//  Created by Mark on 30/11/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "FavIconSelectFromMultipleFavIconsTableViewController.h"
#import "Utils.h"

@interface FavIconSelectFromMultipleFavIconsTableViewController ()

@end

@implementation FavIconSelectFromMultipleFavIconsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"favicon-downloaded-candidate" forIndexPath:indexPath];
    
    cell.textLabel.text = self.node.title;
    
    UIImage* image = self.images[indexPath.row];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%dx%d", (int)image.size.width, (int)image.size.height];
    
    if(image.size.height != 32 || image.size.width != 32) {
        image = scaleImage(image, CGSizeMake(32, 32));
    }
    cell.imageView.image = image;

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
