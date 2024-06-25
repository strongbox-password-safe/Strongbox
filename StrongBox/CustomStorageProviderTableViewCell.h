//
//  CustomStorageProviderTableViewCell.h
//  StrongBox
//
//  Created by Mark on 08/09/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomStorageProviderTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *text;
@property (weak, nonatomic) IBOutlet UILabel *labelSubTitle;

@end
