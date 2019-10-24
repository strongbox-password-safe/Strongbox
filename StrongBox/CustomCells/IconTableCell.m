//
//  IconTableCell.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "IconTableCell.h"
#import "AutoCompleteTextField.h"
#import "FontManager.h"

@interface IconTableCell ()

@property (weak, nonatomic) IBOutlet UIImageView *iconImage;
@property (weak, nonatomic) IBOutlet AutoCompleteTextField *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *horizontalLine;

@property BOOL useEasyReadFont;
@property BOOL selectAllOnEdit;

@end

@implementation IconTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onIconTap)];
    singleTap.numberOfTapsRequired = 1;
    [self.iconImage addGestureRecognizer:singleTap];
    

    if (@available(iOS 13.0, *)) {
        self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
    } else {
        self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
    }
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.onEdited = ^(NSString * _Nonnull text) {
        [self onTitleValueEdited];
    };
    self.titleLabel.font = self.configuredValueFont;

    self.selectAllOnEdit = NO;
    
    UITapGestureRecognizer *cellSingleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onCellTap:)];
    [cellSingleTap setNumberOfTapsRequired:1];
    [cellSingleTap setNumberOfTouchesRequired:1];
    [self addGestureRecognizer:cellSingleTap];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onIconTapped = nil;
    
    self.selectAllOnEdit = NO;
    
    self.titleLabel.text = @"";
    self.titleLabel.tag = 0;
    self.titleLabel.enabled = NO;
    self.titleLabel.placeholder = @"";
    self.titleLabel.font = self.configuredValueFont;
    
    if (@available(iOS 13.0, *)) {
        self.horizontalLine.backgroundColor = UIColor.labelColor;
    } else {
        self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
    }

    self.onTitleEdited = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)setModel:(NSString*)value
            icon:(UIImage*)icon
         editing:(BOOL)editing
 selectAllOnEdit:(BOOL)selectAllOnEdit
 useEasyReadFont:(BOOL)useEasyReadFont {
    self.titleLabel.text = value;
    self.titleLabel.enabled = editing;
    self.titleLabel.accessibilityLabel = @"Title Text Field";
    
    NSString* key = NSLocalizedString(@"generic_fieldname_title", @"Title");
    self.titleLabel.accessibilityLabel = [key stringByAppendingString:NSLocalizedString(@"generic_kv_cell_value_text_accessibility label_fmt", @" Text Field")];

    if (@available(iOS 13.0, *)) {
        self.titleLabel.textColor = UIColor.labelColor;
    } else {
        self.titleLabel.textColor = UIColor.darkTextColor;
    }
    
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;

    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    self.useEasyReadFont = useEasyReadFont;
    self.titleLabel.font = self.configuredValueFont;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.iconImage.image = icon;
    self.iconImage.hidden = icon == nil;

    //
    
#ifndef IS_APP_EXTENSION
    if(editing) {
        if (@available(iOS 13.0, *)) {
            self.iconImage.layer.borderColor = UIColor.labelColor.CGColor;
        }
        else {
            self.iconImage.layer.borderColor = UIColor.blueColor.CGColor;
        }
        self.iconImage.layer.borderWidth = 0.5;
        self.iconImage.layer.cornerRadius = 5;
    }
    else {
#endif
        self.iconImage.layer.borderWidth = 0;
#ifndef IS_APP_EXTENSION
    }
#endif
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL ret = [self.titleLabel becomeFirstResponder];
    
    if(self.selectAllOnEdit) {
        [self.titleLabel selectAll:nil];
    }
    
    return ret;
}

- (void)onTitleValueEdited {
    if(self.onTitleEdited) {
        self.onTitleEdited(self.titleLabel.text);
    }
    
    if(self.titleLabel.text.length == 0) {
        self.horizontalLine.backgroundColor = UIColor.redColor;
        self.titleLabel.placeholder = [NSString stringWithFormat:NSLocalizedString(@"generic_kv_cell_value_empty_value_validation_fmt", @"%@ (Required)"),
                                       NSLocalizedString(@"generic_fieldname_title", @"Title")];
    }
    else {
        self.horizontalLine.backgroundColor = UIColor.darkGrayColor;
    }
}

- (void)onIconTap {
    if(self.onIconTapped) {
        self.onIconTapped();
    }
}

- (void)onCellTap:(id)sender {
    if(self.onCellTapped && !self.isEditing) {
        self.onCellTapped();
    }
}

- (UIFont*)configuredValueFont {
    return self.useEasyReadFont ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.title2Font;
}

@end
