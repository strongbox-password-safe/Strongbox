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
@property UIDatePicker* timePicker;
@property (weak, nonatomic) IBOutlet UITextField *dateTextField;
@property (weak, nonatomic) IBOutlet UITextField *timeTextField;

@end

@implementation EditDateCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    [self.datePicker addTarget:self action:@selector(onDateChanged:) forControlEvents:UIControlEventValueChanged];

    self.timePicker = [[UIDatePicker alloc] init];
    self.timePicker.datePickerMode = UIDatePickerModeTime;
    [self.timePicker addTarget:self action:@selector(onDateChanged:) forControlEvents:UIControlEventValueChanged];

    self.dateTextField.inputView = self.datePicker;
    self.dateTextField.placeholder = @"Date";
    
    self.timeTextField.inputView = self.timePicker;
    self.timeTextField.placeholder = @"Time";
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
}

- (void)onDateChanged:(id)sender {
    UIDatePicker* picker = (UIDatePicker*)sender;
    [self setDate:picker.date];
    
    if(self.onDateChanged) {
        self.onDateChanged(picker.date);
    }
}

//- (void)onTextFieldChanged:(id)sender {
//    NSDateFormatter *df = [[NSDateFormatter alloc] init];
//
//    df.timeStyle = kCFDateFormatterShortStyle;
//    df.dateStyle = NSDateFormatterShortStyle;
//
//    df.locale = NSLocale.currentLocale;
//
//    NSDate* date = [df dateFromString:self.dateTextField.text];
//
//    self.dateTextField.textColor = date ? nil : UIColor.redColor;
//
//    if(date) {
//        if(self.onDateChanged) {
//            self.onDateChanged(date);
//        }
//    }
//    else if(self.dateTextField.text.length == 0) {
//        if(self.onDateChanged) {
//            self.onDateChanged(nil);
//        }
//    }
//    else {
//        NSLog(@"Cannot parse, not changing...");
//    }
//}

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
