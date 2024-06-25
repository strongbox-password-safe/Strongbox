//
//  AddNewVirtualYubiKeyController.m
//  Strongbox
//
//  Created by Strongbox on 17/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AddNewVirtualYubiKeyController.h"
#import "Utils.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "VirtualYubiKeys.h"

@interface AddNewVirtualYubiKeyController ()

@property (weak, nonatomic) IBOutlet UITextField *textFieldName;
@property (weak, nonatomic) IBOutlet UITextField *textFieldSecret;
@property (weak, nonatomic) IBOutlet UISwitch *switchAutoFillOnly;
@property (weak, nonatomic) IBOutlet UISwitch *switchFixedLengthOnly;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAdd;

@end

@implementation AddNewVirtualYubiKeyController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self validateUi];
}

- (void)validateUi {
    BOOL valid = self.textFieldName.text.length > 0 && self.textFieldSecret.text.length && self.textFieldSecret.text.isHexString;
    
    self.buttonAdd.enabled = valid;
}

- (IBAction)onTextChanged:(id)sender {
    [self validateUi];
}

- (IBAction)onAdd:(id)sender {
    NSData* yubikeySecretData = self.textFieldSecret.text.dataFromHex;
    
    NSString* hexSecret = [NSString stringWithFormat:@"%@%@", self.switchFixedLengthOnly.on ? @"P" : @"", yubikeySecretData.upperHexString];
    VirtualYubiKey *key = [VirtualYubiKey keyWithName:self.textFieldName.text secret:hexSecret autoFillOnly:self.switchAutoFillOnly.on];
    
    [VirtualYubiKeys.sharedInstance addKey:key];
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
