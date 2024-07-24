//
//  SystemTrayViewController.m
//  MacBox
//
//  Created by Strongbox on 18/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SystemTrayViewController.h"
#import "PasswordMaker.h"
#import "Settings.h"
#import "ColoredStringHelper.h"
#import "ClickableTextField.h"
#import "Settings.h"
#import "ClipboardManager.h"
#import "MBProgressHUD.h"
#import "AppDelegate.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

#import "MacDatabasePreferences.h"

@interface SystemTrayViewController () 

@property (weak) IBOutlet ClickableTextField *basic;
@property (weak) IBOutlet ClickableTextField *diceWare;
@property (weak) IBOutlet NSButton *buttonRefresh;
@property (weak) IBOutlet NSSlider *sliderLength;
@property (weak) IBOutlet NSSegmentedControl *segmentCharacters;
@property (weak) IBOutlet NSTextField *labelLength;

@property (weak) IBOutlet NSView *miniPasswordGenerator;
@property (weak) IBOutlet NSButton *buttonPasswordPreferences;
@property (weak) IBOutlet NSBox *horizontRuleAfterPasswordGen;
@property (weak) IBOutlet NSLayoutConstraint *constraintGapDatabasesAndPasswordGen;
@property (weak) IBOutlet NSButton *barButtonDice;
@property (weak) IBOutlet NSButton *barButtonPreferences;
@property (weak) IBOutlet NSStackView *databasesStack;

@property NSFont* fontMenlo;

@property NSString* currentBasic;
@property NSString* currentDiceware;

@end

@implementation SystemTrayViewController

+ (instancetype)instantiateFromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"SystemTrayViewController" bundle:nil];
    return [sb instantiateInitialController];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.fontMenlo = [NSFontManager.sharedFontManager fontWithFamily:@"Menlo" traits:kNilOptions weight:NSFontWeightRegular size:16.0];
    
    [self.buttonRefresh setImage:[NSImage imageWithSystemSymbolName:@"arrow.triangle.2.circlepath" accessibilityDescription:nil]];
    [self.buttonRefresh setControlSize:NSControlSizeLarge];
    
    [self.buttonPasswordPreferences setImage:[NSImage imageWithSystemSymbolName:@"gear" accessibilityDescription:nil]];
    [self.buttonPasswordPreferences setControlSize:NSControlSizeLarge];
    
    [self.barButtonDice setImage:[NSImage imageWithSystemSymbolName:@"dice" accessibilityDescription:nil]];
    [self.barButtonDice setControlSize:NSControlSizeLarge];
    
    [self.barButtonPreferences setImage:[NSImage imageWithSystemSymbolName:@"gear" accessibilityDescription:nil]];
    [self.barButtonPreferences setControlSize:NSControlSizeLarge];
    
    self.basic.onClick = ^{
        [self onBasicClick];
    };
    self.diceWare.onClick = ^{
        [self onDiceClick];
    };
    
    [self bindUI];
    
    [self sizeAndPositionPopoverToFit];
}

- (void)viewWillAppear {
    [super viewWillAppear];


    
    [self bindUI];
    
    [self sizeAndPositionPopoverToFit];
    
    [self onRefresh:nil];
}

- (void)bindUI {
    [self bindPasswordUI];
            
    
    
    NSArray<NSView*>* views = self.databasesStack.views.copy;
    for (NSView* view in views) {
        [view removeFromSuperview];
    }
    
    NSArray<MacDatabasePreferences*> *databases = MacDatabasePreferences.allDatabases;

    
    
    for (MacDatabasePreferences* db in databases ) {
        NSButton* databaseButton = [self createDatabaseButton:db];
        [self.databasesStack addView:databaseButton inGravity:NSStackViewGravityBottom];
    }
}

- (NSButton*)createDatabaseButton:(MacDatabasePreferences*)db {
    NSButton* databaseButton = [NSButton buttonWithTitle:db.nickName target:self action:@selector(onDatabaseClicked:)];
    databaseButton.identifier = db.uuid;
    
    [databaseButton setTitle:db.nickName];
    [databaseButton setControlSize:NSControlSizeLarge];
    
    [databaseButton setFrameSize:NSMakeSize(300.,50.)];
    databaseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [databaseButton.widthAnchor constraintEqualToConstant: 300.].active = YES;
    
    return databaseButton;
}

- (void)bindPasswordUI {
    PasswordGenerationConfig* config = Settings.sharedInstance.trayPasswordGenerationConfig;
    
    self.labelLength.stringValue = @(config.basicLength).stringValue;
    self.sliderLength.integerValue = config.basicLength;
    
    [self.segmentCharacters setSelected:NO forSegment:0];
    [self.segmentCharacters setSelected:NO forSegment:1];
    [self.segmentCharacters setSelected:NO forSegment:2];
    [self.segmentCharacters setSelected:NO forSegment:3];
    [self.segmentCharacters setSelected:NO forSegment:4];
    
    for (NSNumber* num in config.useCharacterGroups ) {
        if ( num.integerValue == kPasswordGenerationCharacterPoolUpper ) {
            [self.segmentCharacters setSelected:YES forSegment:0];
        }
        else if ( num.integerValue == kPasswordGenerationCharacterPoolLower ) {
            [self.segmentCharacters setSelected:YES forSegment:1];
        }
        else if ( num.integerValue == kPasswordGenerationCharacterPoolNumeric ) {
            [self.segmentCharacters setSelected:YES forSegment:2];
        }
        else if ( num.integerValue == kPasswordGenerationCharacterPoolSymbols ) {
            [self.segmentCharacters setSelected:YES forSegment:3];
        }
        else if ( num.integerValue == kPasswordGenerationCharacterPoolLatin1Supplement ) {
            [self.segmentCharacters setSelected:YES forSegment:4];
        }
    }
    
    BOOL showPasswordGen = NO; 
    
    self.miniPasswordGenerator.hidden = !showPasswordGen;
    
    self.horizontRuleAfterPasswordGen.hidden = showPasswordGen;
    self.constraintGapDatabasesAndPasswordGen.constant = showPasswordGen ? 0 : 4;
}

- (void)onDatabaseClicked:(id)sender {
    NSButton* button = (NSButton*)sender;
    
    NSString* databaseUuid = button.identifier;
    

    
    if ( self.onShowClicked ) {
        self.onShowClicked( databaseUuid );
    }
}

- (void)sizeAndPositionPopoverToFit {
    CGSize old = self.view.frame.size;
    CGSize fit = [self.view fittingSize];

    CGFloat deltaX = 0.0f; 
    CGFloat deltaY = old.height - fit.height;



    [self.popover setContentSize:CGSizeMake(self.popover.contentSize.width - deltaX, self.popover.contentSize.height - deltaY)];

    NSWindow* popoverWindow = self.view.window;
    if ( popoverWindow ) {
        [popoverWindow setFrame:CGRectOffset(popoverWindow.frame, 0, 13) display:NO];
    }
}

- (IBAction)onSegmentControl:(id)sender {
    BOOL upper = [self.segmentCharacters isSelectedForSegment:0];
    BOOL lower = [self.segmentCharacters isSelectedForSegment:1];
    BOOL numeric = [self.segmentCharacters isSelectedForSegment:2];
    BOOL symbol = [self.segmentCharacters isSelectedForSegment:3];
    BOOL latin1 = [self.segmentCharacters isSelectedForSegment:4];

    NSMutableArray* arr = NSMutableArray.array;
    if ( upper ) {
        [arr addObject:@(kPasswordGenerationCharacterPoolUpper)];
    }
    if ( lower ) {
        [arr addObject:@(kPasswordGenerationCharacterPoolLower)];
    }
    if ( numeric ) {
        [arr addObject:@(kPasswordGenerationCharacterPoolNumeric)];
    }
    if ( symbol ) {
        [arr addObject:@(kPasswordGenerationCharacterPoolSymbols)];
    }
    if ( latin1 ) {
        [arr addObject:@(kPasswordGenerationCharacterPoolLatin1Supplement)];
    }

    if ( arr.count ) { 
        PasswordGenerationConfig* config = Settings.sharedInstance.trayPasswordGenerationConfig;

        config.useCharacterGroups = arr.copy;
        
        Settings.sharedInstance.trayPasswordGenerationConfig = config;
    }
    
    [self bindUI];
    
    [self onRefresh:nil];
}

- (IBAction)onSlider:(id)sender {
    PasswordGenerationConfig* config = Settings.sharedInstance.trayPasswordGenerationConfig;

    config.basicLength = self.sliderLength.integerValue;

    Settings.sharedInstance.trayPasswordGenerationConfig = config;

    [self bindUI];
    
    [self onRefresh:nil];
}

- (IBAction)onRefresh:(id)sender {
    PasswordGenerationConfig* basicConfig = Settings.sharedInstance.trayPasswordGenerationConfig;

    self.currentBasic = [PasswordMaker.sharedInstance generateBasicForConfig:basicConfig];
    
    
    
    self.currentDiceware = [PasswordMaker.sharedInstance generateDicewareForConfig:Settings.sharedInstance.passwordGenerationConfig];

    


    
    self.basic.attributedStringValue = [self getAttributedString:self.currentBasic];
    self.diceWare.attributedStringValue = [self getAttributedString:self.currentDiceware allowMultiLine:YES];
    



    
    self.view.needsLayout = YES;
    
    [self.view updateConstraints];
    
    [self.view layoutSubtreeIfNeeded];
    [self.view layout];
}

- (NSAttributedString*)getAttributedString:(NSString*)string {
    return [self getAttributedString:string allowMultiLine:NO];
}

- (NSAttributedString*)getAttributedString:(NSString*)string allowMultiLine:(BOOL)allowMultiLine {
    BOOL colorize = Settings.sharedInstance.colorizePasswords;
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    BOOL dark = ([osxMode isEqualToString:@"Dark"]);
    BOOL colorBlind = Settings.sharedInstance.colorizeUseColorBlindPalette;

    NSAttributedString* ret = [ColoredStringHelper getColorizedAttributedString:string
                                                    colorize:colorize
                                                    darkMode:dark
                                                  colorBlind:colorBlind
                                                        font:nil];
    
    NSMutableAttributedString* text = ret.mutableCopy;
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = allowMultiLine ? NSLineBreakByCharWrapping : NSLineBreakByTruncatingMiddle;
    style.alignment = NSTextAlignmentCenter;
    
    [text addAttribute:NSParagraphStyleAttributeName
                          value:style
                          range:NSMakeRange(0, text.length)];
    
    [text addAttribute:NSFontAttributeName value:self.fontMenlo range:NSMakeRange(0, text.length)];
    
    CGRect rc = [text boundingRectWithSize:CGSizeMake(295, 0) options:NSStringDrawingUsesLineFragmentOrigin];


    NSAttributedString* ellipsis = [[NSAttributedString alloc] initWithString:@"..." attributes:@{ NSFontAttributeName : self.fontMenlo }];

    int truncateCharacterCount = 0;
    while ( rc.size.height > 48.0 ) {
        text = [text attributedSubstringFromRange:NSMakeRange(0, text.length - 1)].mutableCopy;
        
        NSMutableAttributedString* foo = text.mutableCopy;
        [foo appendAttributedString:ellipsis];
        
        rc = [foo boundingRectWithSize:CGSizeMake(295, 0) options:NSStringDrawingUsesLineFragmentOrigin];

        
        truncateCharacterCount++;
    }
    
    if ( truncateCharacterCount > 0 ) {
        [text appendAttributedString:ellipsis];
    }
    
    return text;
}

- (void)onBasicClick {
    [ClipboardManager.sharedInstance copyConcealedString:self.currentBasic];
    
    [self showToastNotification:NSLocalizedString(@"item_details_password_copied", @"Password Copied") view:self.basic];
}

- (void)onDiceClick {
    [ClipboardManager.sharedInstance copyConcealedString:self.currentDiceware];

    [self showToastNotification:NSLocalizedString(@"item_details_password_copied", @"Password Copied") view:self.diceWare];
}

- (void)showToastNotification:(NSString*)message view:(NSView*)view {

    CIColor* c = [CIColor colorWithCGColor:NSColor.systemBlueColor.CGColor];
    
    NSColor *defaultColor = [NSColor colorWithDeviceRed:c.red
                                                  green:c.green
                                                   blue:c.blue
                                                  alpha:c.alpha];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    
    hud.labelText = message;
    hud.color = defaultColor;
    hud.mode = MBProgressHUDModeText;
    hud.margin = 0.0f;
    hud.yOffset = 2.0f;
    hud.removeFromSuperViewOnHide = YES;
    hud.dismissible = NO;
    hud.cornerRadius = 5.0f;
    hud.dimBackground = YES;
    
    NSTimeInterval delay = 1.0f;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud hide:YES];
    });
}

- (IBAction)onShowStrongbox:(id)sender {
    if ( self.onShowClicked ) {
        self.onShowClicked( nil );
    }
}

- (IBAction)onQuit:(id)sender {  
    [NSApplication.sharedApplication terminate:nil];
}

- (IBAction)onShowPasswordGenerator:(id)sender {





    
    [self onPasswordPreferences:nil];
}

- (IBAction)onPasswordPreferences:(id)sender {
    if ( self.onShowClicked ) { 
        self.onShowClicked( nil );
    }


    
    [PasswordGenerator.sharedInstance show];
}

- (IBAction)onShowPreferences:(id)sender {
    if ( self.onShowClicked ) {
        self.onShowClicked( nil );
    }
    
    [AppSettingsWindowController.sharedInstance showGeneralTab];
}

@end

