//
//  EditDateCell.m
//  Strongbox
//
//  Created by Mark on 28/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "EditDateCell.h"

@interface EditDateCell ()

@property UIDatePicker* datePicker;
@property UIDatePicker* timePicker;
@property (weak, nonatomic) IBOutlet UITextField *dateTextField;
@property (weak, nonatomic) IBOutlet UITextField *timeTextField;

@property UIBarButtonItem* clearButton;
@property UIBarButtonItem* clearButton2;

@property (weak, nonatomic) IBOutlet UIButton *buttonClear;

@end

@implementation EditDateCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    self.timePicker = [[UIDatePicker alloc] init];
    self.timePicker.datePickerMode = UIDatePickerModeTime;
    
    
    
    self.datePicker.preferredDatePickerStyle = UIDatePickerStyleInline; 
    self.timePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    
    
    
    UIToolbar* toolbarDate = [[UIToolbar alloc] init];
    UIToolbar* toolbarTime = [[UIToolbar alloc] init];
    
    toolbarDate.barStyle = UIBarStyleDefault;
    toolbarTime.barStyle = UIBarStyleDefault;
    
    [toolbarDate setTranslucent:YES];
    [toolbarTime setTranslucent:YES];
    
    [toolbarDate sizeToFit];
    [toolbarTime sizeToFit];
    
    UIBarButtonItem* setDateButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_set", @"Set")
                                                                      style:UIBarButtonItemStyleDone
                                                                     target:self
                                                                     action:@selector(onDoneDateToolbarButton)];
    
    UIBarButtonItem* setTimeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_set", @"Set")
                                                                      style:UIBarButtonItemStyleDone
                                                                     target:self
                                                                     action:@selector(onDoneTimeToolbarButton)];
    
    UIBarButtonItem* spaceButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                 target:nil
                                                                                 action:nil];
    
    UIBarButtonItem* spaceButton2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                  target:nil
                                                                                  action:nil];
    
    self.clearButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_clear", @"Clear")
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(clearDate:)];
    
    self.clearButton2 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_clear", @"Clear")
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(clearDate:)];
    
    UIBarButtonItem* cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(onCancelToolbarButton)];
    
    UIBarButtonItem* cancelButton2 = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"generic_cancel", @"Cancel")
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(onCancelToolbarButton)];
    
    [toolbarDate setItems:@[cancelButton, self.clearButton, spaceButton, setDateButton] animated:NO];
    [toolbarTime setItems:@[cancelButton2, self.clearButton2, spaceButton2, setTimeButton] animated:NO];
    
    toolbarDate.userInteractionEnabled = YES;
    toolbarTime.userInteractionEnabled = YES;
    
    
    
    self.dateTextField.inputView = self.datePicker;
    self.dateTextField.placeholder = NSLocalizedString(@"edit_date_cell_date_field_placeholder", @"Date");
    self.dateTextField.accessibilityLabel = NSLocalizedString(@"edit_date_cell_date_field_accessibility_label", @"Date Text Field");
    self.dateTextField.inputAccessoryView = toolbarDate;
    
    self.timeTextField.inputView = self.timePicker;
    self.timeTextField.placeholder = NSLocalizedString(@"edit_date_cell_time_field_placeholder", @"Time");
    self.timeTextField.accessibilityLabel = NSLocalizedString(@"edit_date_cell_time_field_accessibility_label", @"Time Text Field");
    self.timeTextField.inputAccessoryView = toolbarTime;
    
    [self.buttonClear setImage:[UIImage systemImageNamed:@"xmark.circle"] forState:UIControlStateNormal];
    [self.buttonClear setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]
                                      forImageInState:UIControlStateNormal];
    
    self.buttonClear.tintColor = UIColor.systemOrangeColor;
}

- (void)onDoneDateToolbarButton {
    [self setDate:self.datePicker.date];

    if(self.onDateChanged) {
        self.onDateChanged(self.datePicker.date);
    }
    
    [self.dateTextField resignFirstResponder];
}

- (void)onDoneTimeToolbarButton {
    [self setDate:self.timePicker.date];

    if(self.onDateChanged) {
        self.onDateChanged(self.timePicker.date);
    }
    
    [self.timeTextField resignFirstResponder];
}

- (void)onCancelToolbarButton {
    [self.dateTextField resignFirstResponder];
    [self.timeTextField resignFirstResponder];
}

- (IBAction)clearDate:(id)sender {
    [self.dateTextField resignFirstResponder];
    [self.timeTextField resignFirstResponder];
    
    [self setDate:nil];
    
    if(self.onDateChanged) {
        self.onDateChanged(nil);
    }
}

- (void)setDate:(NSDate *)date {
    self.dateTextField.text = dateString(date);
    self.timeTextField.text = timeString(date);

    if(date) {
        self.datePicker.date = date;
        self.timePicker.date = date;
    }
    
    self.clearButton.enabled = date != nil;
    self.clearButton2.enabled = date != nil;
    
    self.buttonClear.enabled = date != nil;
    self.buttonClear.tintColor = date != nil ? UIColor.systemOrangeColor : UIColor.clearColor;
}

static NSString *timeString(NSDate *modDate) {
    if(!modDate) {
        return @"";
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterNoStyle;
    
    df.locale = NSLocale.currentLocale;
    
    return [df stringFromDate:modDate];
}

static NSString *dateString(NSDate *modDate) {
    if(!modDate) {
        return @"";
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];

    df.timeStyle = NSDateFormatterNoStyle;
    df.dateStyle = NSDateFormatterShortStyle;

    df.locale = NSLocale.currentLocale;
    
    return [df stringFromDate:modDate];
}

@end
