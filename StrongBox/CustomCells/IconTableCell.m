//
//  IconTableCell.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
@property (weak, nonatomic) IBOutlet UIButton *buttonCofigureDefaults;
@property (weak, nonatomic) IBOutlet UIStackView *stackConfigureDefaults;

@end

@implementation IconTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onIconTap)];
    singleTap.numberOfTapsRequired = 1;
    [self.iconImage addGestureRecognizer:singleTap];
    

    self.horizontalLine.backgroundColor = UIColor.secondaryLabelColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    
    self.titleLabel.onEdited = ^(NSString * _Nonnull text) {
        [self onTitleValueEdited];
    };
    self.titleLabel.font = self.configuredValueFont;

    self.selectAllOnEdit = NO;
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
    
    self.horizontalLine.backgroundColor = UIColor.labelColor;
    self.onTitleEdited = nil;
    
    self.accessoryType = UITableViewCellAccessoryNone;
    self.editingAccessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)setModel:(NSString*)value
            icon:(UIImage*)icon
         editing:(BOOL)editing
        newEntry:(BOOL)newEntry
 selectAllOnEdit:(BOOL)selectAllOnEdit
 useEasyReadFont:(BOOL)useEasyReadFont {
    self.titleLabel.text = value;
    self.titleLabel.enabled = editing;
    self.titleLabel.accessibilityLabel = @"Title Text Field";
    
    NSString* key = NSLocalizedString(@"generic_fieldname_title", @"Title");
    self.titleLabel.accessibilityLabel = [key stringByAppendingString:NSLocalizedString(@"generic_kv_cell_value_text_accessibility label_fmt", @" Text Field")];

    self.titleLabel.textColor = UIColor.labelColor;
    self.selectAllOnEdit = selectAllOnEdit;
    
    self.horizontalLine.hidden = !editing;

    self.selectionStyle = editing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    self.useEasyReadFont = useEasyReadFont;
    self.titleLabel.font = self.configuredValueFont;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    self.iconImage.image = icon;
    self.iconImage.hidden = icon == nil;

    
    
#ifndef IS_APP_EXTENSION
    self.stackConfigureDefaults.hidden = !newEntry;
#else
    self.stackConfigureDefaults.hidden = YES;
#endif
    
    
    
#ifndef IS_APP_EXTENSION
    if(editing) {
        self.iconImage.layer.borderColor = UIColor.labelColor.CGColor;
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
        self.horizontalLine.backgroundColor = UIColor.systemOrangeColor;
        self.titleLabel.placeholder = NSLocalizedString(@"generic_fieldname_title", @"Title");
        
        
          
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

- (UIFont*)configuredValueFont {
    return self.useEasyReadFont ? FontManager.sharedInstance.easyReadFont : FontManager.sharedInstance.title2Font;
}

- (IBAction)onConfigureDefaults:(id)sender {
    if ( self.onConfigureDefaultsTapped ) {
        self.onConfigureDefaultsTapped();
    }
}

@end
