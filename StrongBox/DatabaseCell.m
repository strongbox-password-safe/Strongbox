//
//  DatabaseCell.m
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "DatabaseCell.h"

NSString* const kDatabaseCell = @"DatabaseCell";

@interface DatabaseCell ()

@property (weak, nonatomic) IBOutlet UIImageView *providerIcon;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UIImageView *statusImage;
@property (weak, nonatomic) IBOutlet UILabel *subtitle1;
@property (weak, nonatomic) IBOutlet UILabel *subtitle2;
@property (weak, nonatomic) IBOutlet UILabel *topSubtitle;
@property (weak, nonatomic) IBOutlet UIView *bottomRow;

@end

@implementation DatabaseCell

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.bottomRow.hidden = NO;
    self.subtitle1.hidden = NO;
    self.subtitle2.hidden = NO;
    self.statusImage.hidden = NO;
    self.topSubtitle.hidden = NO;
}

- (void)setEnabled:(BOOL)enabled {
    self.imageView.userInteractionEnabled = enabled;
    self.userInteractionEnabled = enabled;
    self.textLabel.enabled = enabled;
    self.detailTextLabel.enabled = enabled;
    self.name.enabled = enabled;
    self.subtitle1.enabled = enabled;
    self.subtitle2.enabled = enabled;
    self.providerIcon.userInteractionEnabled = enabled;
    self.statusImage.userInteractionEnabled = enabled;
    self.topSubtitle.enabled = enabled;
}

- (void)set:(NSString*)name
topSubtitle:(NSString*)topSubtitle
  subtitle1:(NSString*)subtitle1
  subtitle2:(NSString*)subtitle2
providerIcon:(UIImage*)providerIcon
statusImage:(UIImage*)statusImage
   disabled:(BOOL)disabled {
    self.name.text = name;

    self.providerIcon.image = providerIcon;
    self.providerIcon.hidden = providerIcon == nil;

    self.statusImage.image = statusImage;

    self.topSubtitle.text = topSubtitle ? topSubtitle : @"";
    self.subtitle1.text = subtitle1 ? subtitle1 : @"";
    self.subtitle2.text = subtitle2 ? subtitle2 : @"";
    
    self.subtitle1.hidden = subtitle1 == nil;
    self.subtitle2.hidden = subtitle2 == nil;
    self.topSubtitle.hidden = topSubtitle == nil;
    
    self.bottomRow.hidden = subtitle1 == nil && subtitle2 == nil;

    [self setEnabled:!disabled];
}

@end
