//
//  WelcomeMasterPasswordViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 05/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WelcomeMasterPasswordViewController.h"
#import "PasswordMaker.h"
#import "WelcomeCreateDoneViewController.h"
#import "AddNewSafeHelper.h"
#import "Alerts.h"
#import "DatabasePreferences.h"
#import "FontManager.h"
#import "PasswordStrengthTester.h"
#import "AppPreferences.h"
#import "PasswordStrengthUIHelper.h"
#import "StrongboxErrorCodes.h"

@interface WelcomeMasterPasswordViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIButton *buttonCreate;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPw;
@property DatabasePreferences* database;
@property NSString* password;

@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;

@property UIButton *checkbox;

@end

@implementation WelcomeMasterPasswordViewController

- (BOOL)shouldAutorotate {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    [self.navigationController setNavigationBarHidden:YES];
    
    self.navigationController.toolbarHidden = YES;
    self.navigationController.toolbar.hidden = YES;
    
    [self.navigationItem setPrompt:nil];
    
    
    [self toggleShowHidePasswordText:self.checkbox];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.textFieldPw becomeFirstResponder];
    
    
    

}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.buttonCreate.layer.cornerRadius = 5.0f;

    [self addShowHideToTextField:self.textFieldPw tag:100 show:NO];

    PasswordGenerationConfig* config = [PasswordGenerationConfig defaults];
    config.algorithm = kPasswordGenerationAlgorithmDiceware; 
    config.wordCount = 5;

#ifdef DEBUG
    self.textFieldPw.text = @"a";
#else
    self.textFieldPw.text = [PasswordMaker.sharedInstance generateForConfigOrDefault:config];
#endif
    [self.textFieldPw addTarget:self
                         action:@selector(textFieldPasswordDidChange:)
               forControlEvents:UIControlEventEditingChanged];
    
    self.textFieldPw.delegate = self;
    self.textFieldPw.font = FontManager.sharedInstance.easyReadFont;
    
    [self bindStrength];
    
    [self validateUi];
}

- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

- (IBAction)onCreate:(id)sender {
    if( [self passwordIsValid] ) {
        self.password = self.textFieldPw.text;
        
        [self create:NO];
    }
}

- (void)create:(BOOL)forceLocal {
    [AddNewSafeHelper createNewExpressDatabase:self
                                          name:self.name
                                      password:self.password
                                    forceLocal:forceLocal
                                    completion:^(BOOL userCancelled, DatabasePreferences * _Nonnull metadata, NSData * _Nonnull initialSnapshot, NSError * _Nonnull error) {
        if (userCancelled) {
            self.onDone(NO, nil);
        }
        else if ( error ) {
            if ( error.code == StrongboxErrorCodes.couldNotCreateICloudFile ) {
                slog(@"WARNWARN: Could not create an iCloud File, switching to Local only because we are in App Onboarding.");
                [self create:YES];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"welcome_vc_error_creating", @"Error Creating Database")
                        error:error
                   completion:^{
                    self.onDone(NO, nil);
                }];
            }
        }
        else {
            self.database = metadata;
            
            NSError* addError;
            if ( ![self.database addWithDuplicateCheck:initialSnapshot initialCacheModDate:NSDate.date error:&addError] ) {
                [Alerts error:self error:addError];
            }
            else {
                [self performSegueWithIdentifier:@"segueToDone" sender:nil];
            }
        }
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if([self passwordIsValid]) {
        [textField resignFirstResponder];
        [self onCreate:nil];
    }
    
    return YES;
}

- (void)validateUi {
    BOOL enabled = [self passwordIsValid];
    self.buttonCreate.enabled = enabled;
    self.buttonCreate.backgroundColor = enabled ? UIColor.systemBlueColor : UIColor.lightGrayColor;
}

- (BOOL)passwordIsValid {
    return self.textFieldPw.text.length;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToDone"]) {
        WelcomeCreateDoneViewController* vc = (WelcomeCreateDoneViewController*)segue.destinationViewController;
        
        vc.onDone = self.onDone;
        vc.database = self.database;
        vc.password = self.password;
    }
}

- (void)addShowHideToTextField:(UITextField*)textField tag:(NSInteger)tag show:(BOOL)show {
    self.checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
    UIButton* checkbox = self.checkbox;
    
    [checkbox setFrame:CGRectMake(2 , 2, 24, 24)];  
    [checkbox setTag:tag]; 
    
    [checkbox addTarget:self action:@selector(toggleShowHidePasswordText:) forControlEvents:UIControlEventTouchUpInside];
    
    [checkbox setAccessibilityLabel:NSLocalizedString(@"welcome_vc_accessibility_show_hide_password", @"Show/Hide Password")];
    
    
    [checkbox.imageView setContentMode:UIViewContentModeScaleAspectFit];
    
    
    UIImage *concealed;
    UIImage *revealed;
    
    concealed = [UIImage systemImageNamed:@"eye"];
    revealed = [UIImage systemImageNamed:@"eye.slash"];
    
    [checkbox setImage:concealed forState:UIControlStateNormal];
    [checkbox setImage:revealed forState:UIControlStateSelected];
    [checkbox setImage:revealed forState:UIControlStateHighlighted];
    
    checkbox.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8); 
                                                              
                                                              

    

    [textField setClearButtonMode:UITextFieldViewModeAlways];
    [textField setRightViewMode:UITextFieldViewModeAlways];
    [textField setRightView:checkbox];
    
    
    
    
    if(show) {
        [checkbox setSelected:YES];
        textField.secureTextEntry = NO;
    }
    else {
        [checkbox setSelected:NO];
        textField.secureTextEntry = YES;
    }
}

- (void)toggleShowHidePasswordText:(UIButton*)sender {
    if(sender.selected){
        [sender setSelected:NO];
    } else {
        [sender setSelected:YES];
    }
    
    self.textFieldPw.secureTextEntry = !sender.selected;
}

- (void)textFieldPasswordDidChange:(id)sender {
    [self validateUi];
    [self bindStrength];
}

- (void)bindStrength {
    [PasswordStrengthUIHelper bindStrengthUI:self.textFieldPw.text
                                      config:AppPreferences.sharedInstance.passwordStrengthConfig
                          emptyPwHideSummary:YES
                                       label:self.labelStrength
                                    progress:self.progressStrength];
}

@end
