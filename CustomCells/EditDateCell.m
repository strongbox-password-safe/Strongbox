//
//  EditDateCell.m
//  Strongbox
//
//  Created by Mark on 28/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "EditDateCell.h"

@interface EditDateCell ()

@property UIDatePicker* datePicker;
@property (weak, nonatomic) IBOutlet UITextField *valueTextField;

@end

@implementation EditDateCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    [self.datePicker addTarget:self action:@selector(onDateChanged:) forControlEvents:UIControlEventValueChanged];
    self.valueTextField.inputView = self.datePicker;
    self.valueTextField.placeholder = @"Never";
    
    [self.valueTextField addTarget:self
                            action:@selector(onTextFieldChanged:)
                  forControlEvents:UIControlEventEditingChanged];
}

- (void)setDate:(NSDate *)date {
    self.valueTextField.text = dateString(date);
}

- (void)onDateChanged:(id)sender {
    [self setDate:self.datePicker.date];
    self.valueTextField.textColor = nil;
    
    if(self.onDateChanged) {
        self.onDateChanged(self.datePicker.date);
    }
}

- (void)onTextFieldChanged:(id)sender {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    df.timeStyle = kCFDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    
    df.locale = NSLocale.currentLocale;
    
    NSDate* date = [df dateFromString:self.valueTextField.text];
    
    self.valueTextField.textColor = date ? nil : UIColor.redColor;
    
    if(date) {
        if(self.onDateChanged) {
            self.onDateChanged(date);
        }
    }
    else if(self.valueTextField.text.length == 0) {
        if(self.onDateChanged) {
            self.onDateChanged(nil);
        }
    }
    else {
        NSLog(@"Cannot parse, not changing...");
    }
}

static NSString *dateString(NSDate *modDate) {
    if(!modDate) {
        return @"";
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];

    df.timeStyle = kCFDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;

    df.locale = NSLocale.currentLocale;
    
    return [df stringFromDate:modDate];
}

@end
