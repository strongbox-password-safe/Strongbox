//
//  EditAttachmentCell.m
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "EditAttachmentCell.h"
#import "FontManager.h"

@implementation EditAttachmentCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.textField.font = FontManager.sharedInstance.regularFont;

    self.textField.adjustsFontForContentSizeCategory = YES;
    
    [self prepareForReuse];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.image.image = nil;
    self.textField.enabled = NO;
    self.textField.textColor = UIColor.labelColor;

    self.textField.tag = 0;
    self.horizontalLine.hidden = YES;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.accessoryType = UITableViewCellAccessoryNone;
}

@end
