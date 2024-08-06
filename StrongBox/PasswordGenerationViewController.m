//
//  PasswordGenerationViewController.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationViewController.h"
#import "SelectItemTableViewController.h"
#import "PasswordMaker.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "Alerts.h"
#import "FontManager.h"
#import "ClipboardManager.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "PasswordStrengthTester.h"
#import "PasswordStrengthUIHelper.h"

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

@interface PasswordGenerationViewController ()

@property PasswordGenerationConfig *config;

@property (weak, nonatomic) IBOutlet UITableViewCell *sample1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBasicLength;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellUseCharacterGroups;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellEasyReadCharactersOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNoneAmbiguousOnly;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellPickFromEveryGroup;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWordCount;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWordLists;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWordSeparator;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellCasing;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellHackerify;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAddSalt;
@property (weak, nonatomic) IBOutlet UISlider *basicLengthSlider;
@property (weak, nonatomic) IBOutlet UILabel *basicLengthLabel;
@property (weak, nonatomic) IBOutlet UISlider *wordCountSlider;
@property (weak, nonatomic) IBOutlet UILabel *wordCountLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellInfoDiceware;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellInfoXkcd;
@property (weak, nonatomic) IBOutlet UIProgressView *progressStrength;
@property (weak, nonatomic) IBOutlet UILabel *labelStrength;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentAlgorithm;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAlgorithm;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellDiceAddANumber;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDiceAddUpper;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDiceAddLower;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDiceAddSymbol;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellDiceAddLatin1;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellBasicExcluded;

@property (weak, nonatomic) IBOutlet UITableViewCell *cellUpper;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLower;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellNumeric;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellSymbols;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellLatin1;
@property (weak, nonatomic) IBOutlet UILabel *labelTapToSetLength;


@end

@implementation PasswordGenerationViewController

- (IBAction)onDone:(id)sender {
    if ( self.onDone ) {
        self.onDone();
    }
    else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

- (UILongPressGestureRecognizer*)makeLongPressGestureRecognizer {
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                                         initWithTarget:self
                                                         action:@selector(onSampleLongPress:)];
    
    longPressRecognizer.minimumPressDuration = 1;
    longPressRecognizer.cancelsTouchesInView = YES;
    
    return longPressRecognizer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.config = AppPreferences.sharedInstance.passwordGenerationConfig;
    
    UILongPressGestureRecognizer* gr1 = [self makeLongPressGestureRecognizer];
    [self.sample1 addGestureRecognizer:gr1];
    
    self.sample1.textLabel.font = FontManager.sharedInstance.easyReadFont;
    
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTappedSetLength)];
    tap.cancelsTouchesInView = YES;
    [self.labelTapToSetLength addGestureRecognizer:tap];
    
    [self.segmentAlgorithm setTitle:NSLocalizedString(@"password_gen_vc_mode_basic_title", @"Basic") forSegmentAtIndex:0];
    [self.segmentAlgorithm setTitle:NSLocalizedString(@"password_gen_vc_mode_diceware_xkcd_title", @"Diceware (XKCD)") forSegmentAtIndex:1];
    
    [self bindUi];
    
    [self refreshGenerated];
}

- (void)onSampleLongPress:(id)sender {
    UIGestureRecognizer* gr = (UIGestureRecognizer*)sender;
    if (gr.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    slog(@"onSampleLongPress");
    UITableViewCell* cell = (UITableViewCell*)gr.view;
    [self copyToClipboard:cell.textLabel.text message:NSLocalizedString(@"password_gen_vc_sample_password_copied", @"Sample Password Copied")];
}

- (void)copyToClipboard:(NSString *)value message:(NSString *)message {
    if (value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
    
#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:message
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

- (IBAction)onWordCountChanged:(id)sender {
    UISlider* slider = (UISlider*)sender;
    self.config.wordCount = (NSInteger)slider.value;
    AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
    
    [self bindWordCountSlider];
    
    [self refreshGenerated];
}

- (void)bindWordCountSlider {
    self.wordCountSlider.value = self.config.wordCount;
    self.wordCountLabel.text = @(self.config.wordCount).stringValue;
}

- (void)onTappedSetLength {
    [Alerts OkCancelWithTextField:self
                    textFieldText:@(self.config.basicLength).stringValue
                            title:NSLocalizedString(@"alert_enter_password_basic_length", @"Enter Length")
                          message:@""
                       completion:^(NSString *text, BOOL response) {
        if ( response && text.intValue ) {
            self.basicLengthSlider.value = text.intValue;
            self.config.basicLength = (NSInteger)self.basicLengthSlider.value;
            AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
            [self bindBasicLengthSlider];
            [self refreshGenerated];
        }
    }];
}

- (IBAction)onBasicLengthChanged:(id)sender {
    UISlider* slider = (UISlider*)sender;
    self.config.basicLength = (NSInteger)slider.value;
    AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
    
    [self bindBasicLengthSlider];
    
    [self refreshGenerated];
}

- (void)bindBasicLengthSlider {
    self.basicLengthSlider.value = self.config.basicLength;
    self.basicLengthLabel.text = @(self.config.basicLength).stringValue;
}

- (void)refreshGenerated {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
    self.sample1.textLabel.attributedText = [ColoredStringHelper getColorizedAttributedString:[self getSamplePassword] colorize:YES darkMode:dark colorBlind:colorBlind font:self.sample1.textLabel.font];
    
    [self bindStrength];
}

- (NSString*)getSamplePassword {
    NSString* str = [PasswordMaker.sharedInstance generateForConfig:self.config];
    return str ? str : NSLocalizedString(@"password_gen_vc_generation_failed", @"<Generation Failed>");
}

- (void)bindUi {
    self.segmentAlgorithm.selectedSegmentIndex = self.config.algorithm == kPasswordGenerationAlgorithmBasic ? 0 : 1;
    
    NSArray<NSString*> *characterGroups = [self.config.useCharacterGroups map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig characterPoolToPoolString:(PasswordGenerationCharacterPool)obj.integerValue];
    }];
    NSString* useGroups = [characterGroups componentsJoinedByString:@", "];
    
    self.cellUseCharacterGroups.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"password_gen_vc_using_character_groups_fmt", @"Using: %@"), useGroups];
    
    self.cellEasyReadCharactersOnly.accessoryType = self.config.easyReadCharactersOnly ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.cellNoneAmbiguousOnly.accessoryType = self.config.nonAmbiguousOnly ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellPickFromEveryGroup.accessoryType = self.config.pickFromEveryGroup ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    
    
    
    
    NSArray* knownWordLists = [self.config.wordLists filter:^BOOL(NSString * _Nonnull obj) {
        return PasswordGenerationConfig.wordListsMap[obj] != nil;
    }];
    
    NSArray<NSString*> *friendlyWordLists = [knownWordLists map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        WordList* list = PasswordGenerationConfig.wordListsMap[obj];
        return list.name;
    }];
    
    NSString* friendlyWordListsCombined = [friendlyWordLists componentsJoinedByString:@", "];
    self.cellWordLists.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"password_gen_vc_using_wordlists_fmt", @"Using: %@"), friendlyWordListsCombined];
    
    self.cellWordSeparator.detailTextLabel.text = self.config.wordSeparator;
    
    self.cellCasing.detailTextLabel.text = [PasswordGenerationConfig getCasingStringForCasing:self.config.wordCasing];
    
    self.cellHackerify.detailTextLabel.text = [PasswordGenerationConfig getHackerifyLevel:self.config.hackerify];
    
    self.cellAddSalt.detailTextLabel.text = [PasswordGenerationConfig getSaltLevel:self.config.saltConfig];
    
    
    
    self.cellDiceAddANumber.accessoryType = self.config.dicewareAddNumber ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellDiceAddUpper.accessoryType = self.config.dicewareAddUpper ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellDiceAddLower.accessoryType = self.config.dicewareAddLower ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellDiceAddSymbol.accessoryType = self.config.dicewareAddSymbols ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellDiceAddLatin1.accessoryType = self.config.dicewareAddLatin1Supplement ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    
    
    self.cellBasicExcluded.detailTextLabel.text = self.config.basicExcludedCharacters.length ? self.config.basicExcludedCharacters : NSLocalizedString(@"generic_none", @"None");
    
    
    
    self.cellUpper.accessoryType = [self.config.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolUpper)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellLower.accessoryType = [self.config.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolLower)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellNumeric.accessoryType = [self.config.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolNumeric)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellSymbols.accessoryType = [self.config.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolSymbols)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellLatin1.accessoryType = [self.config.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolLatin1Supplement)] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    
    
    [self bindBasicLengthSlider];
    [self bindWordCountSlider];
    
    [self bindTableView];
}

- (void)bindTableView {
    
    
    [self cell:self.cellBasicLength setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellUseCharacterGroups setHidden:YES]; 
    [self cell:self.cellEasyReadCharactersOnly setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellNoneAmbiguousOnly setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellPickFromEveryGroup setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellBasicExcluded setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];

    [self cell:self.cellUpper setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellLower setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellNumeric setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellSymbols setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellLatin1 setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];

    
    
    [self cell:self.cellWordCount setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellWordLists setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellWordSeparator setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellCasing setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellHackerify setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellAddSalt setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    
    [self cell:self.cellDiceAddANumber setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellDiceAddUpper setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellDiceAddLower setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellDiceAddSymbol setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellDiceAddLatin1 setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    
#ifdef IS_APP_EXTENSION
    
    [self cell:self.cellInfoXkcd setHidden:YES];
    [self cell:self.cellInfoDiceware setHidden:YES];
#endif
    
    [self reloadDataAnimated:YES];
}

- (IBAction)onChangeAlgorithm:(id)sender {    
    self.config.algorithm = self.segmentAlgorithm.selectedSegmentIndex == 0 ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;
    AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
    
    [self bindUi];
    [self refreshGenerated];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellUseCharacterGroups) {
        [self changeCharacterGroups];
    }
    else if(cell == self.cellEasyReadCharactersOnly) {
        self.config.easyReadCharactersOnly = !self.config.easyReadCharactersOnly;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        
        [self bindUi];
        [self refreshGenerated];
    }
    else if(cell == self.cellNoneAmbiguousOnly) {
        self.config.nonAmbiguousOnly = !self.config.nonAmbiguousOnly;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        
        [self bindUi];
        [self refreshGenerated];
    }
    else if(cell == self.cellPickFromEveryGroup) {
        self.config.pickFromEveryGroup = !self.config.pickFromEveryGroup;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        
        [self bindUi];
        [self refreshGenerated];
    }
    else if(cell == self.cellWordLists) {
        [self changeWordLists];
    }
    else if(cell == self.cellWordSeparator) {
        [self promptForNewWordSeparator];
    }
    else if (cell == self.cellCasing) {
        [self promptForCasing];
    }
    else if (cell == self.cellHackerify) {
        [self promptForHackerifyLevel];
    }
    else if(cell == self.cellAddSalt) {
        [self promptForSaltLevel];
    }
    else if (cell == self.cellInfoDiceware) {
#ifndef IS_APP_EXTENSION
        NSURL* url = [NSURL URLWithString:@"http:
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
#endif
    }
    else if (cell == self.cellInfoXkcd) {
#ifndef IS_APP_EXTENSION
        NSURL* url = [NSURL URLWithString:@"https:
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
#endif
    }
    else if ( cell == self.cellAlgorithm ) {
        
    }
    else if ( cell == self.cellBasicExcluded ) {
        [self promptForExcludedCharacters];
    }
    else if ( cell == self.cellDiceAddANumber ) {
        self.config.dicewareAddNumber = !self.config.dicewareAddNumber;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellDiceAddUpper ) {
        self.config.dicewareAddUpper = !self.config.dicewareAddUpper;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellDiceAddLower ) {
        self.config.dicewareAddLower = !self.config.dicewareAddLower;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellDiceAddSymbol ) {
        self.config.dicewareAddSymbols = !self.config.dicewareAddSymbols;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellDiceAddLatin1 ) {
        self.config.dicewareAddLatin1Supplement = !self.config.dicewareAddLatin1Supplement;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellUpper ) {
        [self toggleCharacterGroup:kPasswordGenerationCharacterPoolUpper];
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellLower ) {
        [self toggleCharacterGroup:kPasswordGenerationCharacterPoolLower];
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellNumeric ) {
        [self toggleCharacterGroup:kPasswordGenerationCharacterPoolNumeric];
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellSymbols ) {
        [self toggleCharacterGroup:kPasswordGenerationCharacterPoolSymbols];
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else if ( cell == self.cellLatin1 ) {
        [self toggleCharacterGroup:kPasswordGenerationCharacterPoolLatin1Supplement];
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    }
    else { 
        [self refreshGenerated];
    }
}

- (void)toggleCharacterGroup:(PasswordGenerationCharacterPool)pool {
    if ( [self.config.useCharacterGroups containsObject:@(pool)] ) {
        if ( self.config.useCharacterGroups.count > 1 ) { 
            [self removeCharacterGroup:pool];
        }
    }
    else {
        [self addCharacterGroup:pool];
    }
}

- (void)removeCharacterGroup:(PasswordGenerationCharacterPool)pool {
    NSMutableArray* mut = self.config.useCharacterGroups.mutableCopy;
    [mut removeObject:@(pool)];
    self.config.useCharacterGroups = mut.copy;
}

- (void)addCharacterGroup:(PasswordGenerationCharacterPool)pool {
    NSMutableArray* mut = self.config.useCharacterGroups.mutableCopy;
    [mut addObject:@(pool)];
    self.config.useCharacterGroups = mut.copy;
}

- (void)promptForSaltLevel {
    NSArray<NSNumber*> *opt = @[@(kPasswordGenerationSaltConfigNone),
                                @(kPasswordGenerationSaltConfigPrefix),
                                @(kPasswordGenerationSaltConfigSprinkle),
                                @(kPasswordGenerationSaltConfigSuffix)];
    
    NSArray<NSString*>* options = [opt map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig getSaltLevel:obj.integerValue];
    }];
    
    NSUInteger index = [opt indexOfObject:@(self.config.saltConfig)];
    
    [self promptForItem:NSLocalizedString(@"password_gen_vc_select_salt_type", @"Select Salt Type")
                options:options
           currentIndex:index
             completion:^(NSInteger selected) {
                 self.config.saltConfig = opt[selected].integerValue;
                 AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                 [self bindUi];
                 [self refreshGenerated];
             }];
}

- (void)promptForHackerifyLevel {
    NSArray<NSNumber*> *opt = @[@(kPasswordGenerationHackerifyLevelNone),
                                @(kPasswordGenerationHackerifyLevelBasicSome),
                                @(kPasswordGenerationHackerifyLevelBasicAll),
                                @(kPasswordGenerationHackerifyLevelProSome),
                                @(kPasswordGenerationHackerifyLevelProAll)];
    
    NSArray<NSString*>* options = [opt map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig getHackerifyLevel:obj.integerValue];
    }];
    
    NSUInteger index = [opt indexOfObject:@(self.config.hackerify)];
    
    [self promptForItem:NSLocalizedString(@"password_gen_vc_select_hacker_level", @"Select l33t Level")
                options:options
           currentIndex:index
             completion:^(NSInteger selected) {
                 self.config.hackerify = opt[selected].integerValue;
                 AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                 [self bindUi];
                 [self refreshGenerated];
             }];
}

- (void)promptForCasing {
    NSArray<NSNumber*> *opt = @[@(kPasswordGenerationWordCasingNoChange),
                                @(kPasswordGenerationWordCasingLower),
                               @(kPasswordGenerationWordCasingUpper),
                               @(kPasswordGenerationWordCasingTitle),
                               @(kPasswordGenerationWordCasingRandom)];
    
    NSArray<NSString*>* options = [opt map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig getCasingStringForCasing:obj.integerValue];
    }];
    
    NSUInteger index = [opt indexOfObject:@(self.config.wordCasing)];
    
    [self promptForItem:NSLocalizedString(@"password_gen_vc_select_casing_type", @"Select Word Casing")
                options:options
           currentIndex:index
             completion:^(NSInteger selected) {
                 self.config.wordCasing = opt[selected].integerValue;
                 AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                 [self bindUi];
                 [self refreshGenerated];
             }];
}

- (void)changeWordLists {
    NSDictionary<NSNumber*, NSArray<WordList*>*>* wordListsByCategory = [PasswordGenerationConfig.wordListsMap.allValues groupBy:^id _Nonnull(WordList * _Nonnull obj) {
        return @(obj.category);
    }];
    
    NSArray<NSNumber*>* categories = @[@(kWordListCategoryStandard),
                                       @(kWordListCategoryFandom),
                                       @(kWordListCategoryLanguages)];

    
    NSArray<NSString*>* headers = [categories map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        if (obj.unsignedIntValue == kWordListCategoryStandard) {
            return NSLocalizedString(@"password_gen_vc_wordlist_category_standard", @"Standard");
        }
        if (obj.unsignedIntValue == kWordListCategoryFandom) {
            return NSLocalizedString(@"password_gen_vc_wordlist_category_fandom", @"Fandom");
        }
        else {
            return NSLocalizedString(@"password_gen_vc_wordlist_category_languages", @"Languages");
        }
    }];
    
    NSArray<NSArray<WordList*>*>* categorizedWordLists = [categories map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return  [wordListsByCategory[obj] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            WordList* v1 = obj1;
            WordList* v2 = obj2;
    
            return finderStringCompare(v1.name, v2.name);
        }];
    }];
    
    NSArray<NSArray<NSString*>*>* friendlyNames = [categorizedWordLists map:^id _Nonnull(NSArray<WordList *> * _Nonnull obj, NSUInteger idx) {
        return [obj map:^id _Nonnull(WordList * _Nonnull obj, NSUInteger idx) {
            return obj.name;
        }];
    }];
    
    NSArray<NSIndexSet*>* selected = [categorizedWordLists map:^id _Nonnull(NSArray<WordList *> * _Nonnull obj, NSUInteger idx) {
        NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
        
        int i = 0;
        for (WordList* wordList in obj) {
            if([self.config.wordLists containsObject:wordList.key]) {
                slog(@"Selecting: %@", wordList.key);
                [indexSet addIndex:i];
            }
            
            i++;
        }
        
        return indexSet;
    }];
        
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.groupItems = friendlyNames;
    vc.groupHeaders = headers;
    vc.selectedIndexPaths = selected;
    vc.multipleSelectMode = YES;
    vc.multipleSelectDisallowEmpty = YES;
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSMutableArray<NSString*>* selectedKeys = @[].mutableCopy;
        
        int category = 0;
        for (NSIndexSet* categorySet in selectedIndices) {
            NSArray<WordList*>* wlc = categorizedWordLists[category];
            
            [categorySet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                WordList* wl = wlc[idx];
                [selectedKeys addObject:wl.key];
            }];

            category++;
        }
        
        self.config.wordLists = selectedKeys;
        AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
        [self bindUi];
        [self refreshGenerated];
    };
    
    vc.title = NSLocalizedString(@"password_gen_vc_select_wordlists", @"Select Word Lists");
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)changeCharacterGroups {
    NSArray<NSNumber*>* pools = @[    @(kPasswordGenerationCharacterPoolUpper),
                                      @(kPasswordGenerationCharacterPoolLower),
                                      @(kPasswordGenerationCharacterPoolNumeric),
                                      @(kPasswordGenerationCharacterPoolSymbols),
                                      @(kPasswordGenerationCharacterPoolLatin1Supplement),

    ];
    
    NSArray<NSString*> *poolsStrings = [pools map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig characterPoolToPoolString:(PasswordGenerationCharacterPool)obj.integerValue];
    }];
    
    NSMutableIndexSet *selected = [NSMutableIndexSet indexSet];
    for (int i=0;i<pools.count;i++) {
        if([self.config.useCharacterGroups containsObject:pools[i]]) {
            [selected addIndex:i];
        }
    }
    
    [self promptForItems:NSLocalizedString(@"password_gen_vc_select_character_groups", @"Select Character Groups")
                 options:poolsStrings
         selectedIndices:selected
              completion:^(NSIndexSet *selected) {
                  NSMutableArray* selectedPools = @[].mutableCopy;
                  [selected enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                      [selectedPools addObject:pools[idx]];
                  }];
                  self.config.useCharacterGroups = selectedPools.copy;
                  AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                  
                  [self bindUi];
                  [self refreshGenerated];
              }];
}

- (void)promptForExcludedCharacters {
    [Alerts OkCancelWithTextField:self
                    textFieldText:self.config.basicExcludedCharacters
                            title:NSLocalizedString(@"password_gen_vc_prompt_excluded_characters", @"Excluded Characters")
                          message:@""
                       completion:^(NSString *text, BOOL response) {
        if(response) {
            self.config.basicExcludedCharacters = text;
            AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
            [self bindUi];
            [self refreshGenerated];
        }
    }];
}

- (void)promptForNewWordSeparator {
    if(self.config.wordSeparator.length) {
        [Alerts OkCancelWithTextField:self
                        textFieldText:self.config.wordSeparator
                                title:NSLocalizedString(@"password_gen_vc_prompt_word_separator", @"Word Separator")
                              message:@""
                           completion:^(NSString *text, BOOL response) {
                               if(response) {
                                   self.config.wordSeparator = text;
                                   AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                                   [self bindUi];
                                   [self refreshGenerated];
                               }
                           }];
    }
    else {
        [Alerts OkCancelWithTextField:self
                textFieldPlaceHolder:NSLocalizedString(@"password_gen_vc_word_separator_placeholder", @"Separator")
                                title:NSLocalizedString(@"password_gen_vc_prompt_word_separator", @"Word Separator")
                              message:@""
                           completion:^(NSString *text, BOOL response) {
                               if(response) {
                                   self.config.wordSeparator = text;
                                   AppPreferences.sharedInstance.passwordGenerationConfig = self.config;
                                   [self bindUi];
                                   [self refreshGenerated];
                               }
                           }];
    }
}

- (void)promptForItem:(NSString*)title
              options:(NSArray<NSString*>*)options
         currentIndex:(NSInteger)currentIndex
           completion:(void(^)(NSInteger selected))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.groupItems = @[options];
    vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentIndex]];
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        [self.navigationController popViewControllerAnimated:YES];
        NSIndexSet* set = selectedIndices.firstObject;
        completion(set.firstIndex);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)promptForItems:(NSString*)title
               options:(NSArray<NSString*>*)options
       selectedIndices:(NSIndexSet*)selectedIndices
            completion:(void(^)(NSIndexSet* selected))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.groupItems = @[options];
    vc.selectedIndexPaths = @[selectedIndices];
    vc.multipleSelectMode = YES;
    vc.multipleSelectDisallowEmpty = YES;
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        completion(set);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}


- (void)bindStrength {
    [PasswordStrengthUIHelper bindStrengthUI:self.sample1.textLabel.text
                                      config:AppPreferences.sharedInstance.passwordStrengthConfig
                          emptyPwHideSummary:NO
                                       label:self.labelStrength
                                    progress:self.progressStrength];
}

@end
