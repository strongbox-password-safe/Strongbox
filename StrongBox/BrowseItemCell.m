//
//  BrowseItemCell.m
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BrowseItemCell.h"
#import "FontManager.h"

@interface BrowseItemCell ()

@property (weak, nonatomic) IBOutlet UIView *bottomRow;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;
@property (weak, nonatomic) IBOutlet UILabel *flagsLabel;
@property (weak, nonatomic) IBOutlet UILabel *childCountLabel;

@end

@implementation BrowseItemCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation {
    self.titleLabel.text = title;
    self.titleLabel.font = italic ? FontManager.sharedInstance.italicFont : FontManager.sharedInstance.regularFont;
    
    self.iconImageView.image = icon;
    self.usernameLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    self.flagsLabel.text = @"";
    self.otpLabel.text = @"";
    self.otpLabel.hidden = YES;
    self.flagsLabel.hidden = YES;

    self.childCountLabel.hidden = childCount.length == 0;
    self.childCountLabel.text = childCount;
    
    self.pathLabel.text = groupLocation;
    self.bottomRow.hidden = groupLocation.length == 0;
}

- (void)setRecord:(NSString *)title username:(NSString *)username icon:(UIImage *)icon groupLocation:(NSString *)groupLocation flags:(NSString*)flags {
    self.titleLabel.text = title;
    self.titleLabel.font = FontManager.sharedInstance.regularFont;
    self.iconImageView.image = icon;
    self.usernameLabel.text = username;
    self.pathLabel.text = groupLocation;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.flagsLabel.text = flags;
    self.flagsLabel.hidden = NO;
    self.childCountLabel.hidden = YES;
    
    self.otpLabel.text = @"";
    self.otpLabel.hidden = NO;

    self.bottomRow.hidden = username.length == 0 && groupLocation.length == 0;
}

@end
