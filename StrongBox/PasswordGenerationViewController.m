//
//  PasswordGenerationViewController.m
//  Strongbox
//
//  Created by Mark on 29/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PasswordGenerationViewController.h"
#import "SelectItemTableViewController.h"
#import "PasswordMaker.h"
#import "NSArray+Extensions.h"
#import "Settings.h"
#import "Utils.h"
#import "Alerts.h"
#import "FontManager.h"
#import "ClipboardManager.h"

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

@interface PasswordGenerationViewController ()

@property PasswordGenerationConfig *config;

@property (weak, nonatomic) IBOutlet UITableViewCell *sample1;
@property (weak, nonatomic) IBOutlet UITableViewCell *sample2;
@property (weak, nonatomic) IBOutlet UITableViewCell *sample3;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellAlgorithm;
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

@end

@implementation PasswordGenerationViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
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
    
    self.config = Settings.sharedInstance.passwordGenerationConfig;

    UILongPressGestureRecognizer* gr1 = [self makeLongPressGestureRecognizer];
    [self.sample1 addGestureRecognizer:gr1];

    UILongPressGestureRecognizer* gr2 = [self makeLongPressGestureRecognizer];
    [self.sample2 addGestureRecognizer:gr2];

    UILongPressGestureRecognizer* gr3 = [self makeLongPressGestureRecognizer];
    [self.sample3 addGestureRecognizer:gr3];

    self.sample1.textLabel.font = FontManager.sharedInstance.easyReadFont;
    self.sample2.textLabel.font = FontManager.sharedInstance.easyReadFont;
    self.sample3.textLabel.font = FontManager.sharedInstance.easyReadFont;
    
    [self bindUi];
    
    [self refreshGenerated];
}

- (void)onSampleLongPress:(id)sender {
    UIGestureRecognizer* gr = (UIGestureRecognizer*)sender;
    if (gr.state != UIGestureRecognizerStateBegan) {
        return;
    }

    NSLog(@"onSampleLongPress");
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
    Settings.sharedInstance.passwordGenerationConfig = self.config;
    
    [self bindWordCountSlider];
    
    [self refreshGenerated];
}

- (void)bindWordCountSlider {
    self.wordCountSlider.value = self.config.wordCount;
    self.wordCountLabel.text = @(self.config.wordCount).stringValue;
}

- (IBAction)onBasicLengthChanged:(id)sender {
    UISlider* slider = (UISlider*)sender;
    self.config.basicLength = (NSInteger)slider.value;
    Settings.sharedInstance.passwordGenerationConfig = self.config;

    [self bindBasicLengthSlider];
    
    [self refreshGenerated];
}

- (void)bindBasicLengthSlider {
    self.basicLengthSlider.value = self.config.basicLength;
    self.basicLengthLabel.text = @(self.config.basicLength).stringValue;
}

- (void)refreshGenerated {
    self.sample1.textLabel.text = [self getSamplePassword];
    self.sample2.textLabel.text = [self getSamplePassword];
    self.sample3.textLabel.text = [self getSamplePassword];
}

- (NSString*)getSamplePassword {
    NSString* str = [PasswordMaker.sharedInstance generateForConfig:self.config];
    return str ? str : NSLocalizedString(@"password_gen_vc_generation_failed", @"<Generation Failed>");
}

- (void)bindUi {
    self.cellAlgorithm.detailTextLabel.text = self.config.algorithm == kPasswordGenerationAlgorithmBasic ? NSLocalizedString(@"password_gen_vc_mode_basic_title", @"Basic") : @"Diceware (XKCD)";
    
    NSArray<NSString*> *characterGroups = [self.config.useCharacterGroups map:^id _Nonnull(NSNumber * _Nonnull obj, NSUInteger idx) {
        return [PasswordGenerationConfig characterPoolToPoolString:(PasswordGenerationCharacterPool)obj.integerValue];
    }];
    NSString* useGroups = [characterGroups componentsJoinedByString:@", "];
    self.cellUseCharacterGroups.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"password_gen_vc_using_character_groups_fmt", @"Using: %@"), useGroups];
    
    self.cellEasyReadCharactersOnly.accessoryType = self.config.easyReadCharactersOnly ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.cellNoneAmbiguousOnly.accessoryType = self.config.nonAmbiguousOnly ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.cellPickFromEveryGroup.accessoryType = self.config.pickFromEveryGroup ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    // Word Lists
    
    // This can happen if we change the key (mostly during development) but for safety include here...
    
    NSArray* knownWordLists = [self.config.wordLists filter:^BOOL(NSString * _Nonnull obj) {
        return PasswordGenerationConfig.wordLists[obj] != nil;
    }];
    
    NSArray<NSString*> *friendlyWordLists = [knownWordLists map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return PasswordGenerationConfig.wordLists[obj];
    }];
    
    NSString* friendlyWordListsCombined = [friendlyWordLists componentsJoinedByString:@", "];
    self.cellWordLists.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"password_gen_vc_using_wordlists_fmt", @"Using: %@"), friendlyWordListsCombined];
    
    self.cellWordSeparator.detailTextLabel.text = self.config.wordSeparator;
    
    self.cellCasing.detailTextLabel.text = [PasswordGenerationConfig getCasingStringForCasing:self.config.wordCasing];
    
    self.cellHackerify.detailTextLabel.text = [PasswordGenerationConfig getHackerifyLevel:self.config.hackerify];
    
    self.cellAddSalt.detailTextLabel.text = [PasswordGenerationConfig getSaltLevel:self.config.saltConfig];
    
    [self bindBasicLengthSlider];
    [self bindWordCountSlider];
    
    [self bindTableView];
}

- (void)bindTableView {
    // Basic
    
    [self cell:self.cellBasicLength setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellUseCharacterGroups setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellEasyReadCharactersOnly setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellNoneAmbiguousOnly setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellPickFromEveryGroup setHidden:(self.config.algorithm != kPasswordGenerationAlgorithmBasic)];
    
    // Diceware

    [self cell:self.cellWordCount setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellWordLists setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellWordSeparator setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellCasing setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellHackerify setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    [self cell:self.cellAddSalt setHidden:(self.config.algorithm == kPasswordGenerationAlgorithmBasic)];
    
    
#ifdef IS_APP_EXTENSION
    // Hide These info cells for App Extensions as we cannot launch a url from there...
    [self cell:self.cellInfoXkcd setHidden:YES];
    [self cell:self.cellInfoDiceware setHidden:YES];
#endif

    [self reloadDataAnimated:YES];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellAlgorithm) {
        [self promptForItem:NSLocalizedString(@"password_gen_vc_select_mode", @"Select Algorithm")
                    options:@[NSLocalizedString(@"password_gen_vc_mode_basic_title", @"Basic"),
                              @"Diceware (XKCD)"]
               currentIndex:self.config.algorithm == kPasswordGenerationAlgorithmBasic ? 0 : 1
                 completion:^(NSInteger selected) {
                     self.config.algorithm = selected == 0 ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;
                     Settings.sharedInstance.passwordGenerationConfig = self.config;
                     [self bindUi];
                     [self refreshGenerated];
                 }];
    }
    else if(cell == self.cellUseCharacterGroups) {
        [self changeCharacterGroups];
    }
    else if(cell == self.cellEasyReadCharactersOnly) {
        self.config.easyReadCharactersOnly = !self.config.easyReadCharactersOnly;
        Settings.sharedInstance.passwordGenerationConfig = self.config;

        [self bindUi];
        [self refreshGenerated];
    }
    else if(cell == self.cellNoneAmbiguousOnly) {
        self.config.nonAmbiguousOnly = !self.config.nonAmbiguousOnly;
        Settings.sharedInstance.passwordGenerationConfig = self.config;

        [self bindUi];
        [self refreshGenerated];
    }
    else if(cell == self.cellPickFromEveryGroup) {
        self.config.pickFromEveryGroup = !self.config.pickFromEveryGroup;
        Settings.sharedInstance.passwordGenerationConfig = self.config;

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
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://world.std.com/~reinhold/diceware.html"] options:@{} completionHandler:nil];
#endif
    }
    else if (cell == self.cellInfoXkcd) {
#ifndef IS_APP_EXTENSION
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://xkcd.com/936/"] options:@{} completionHandler:nil];
#endif
    }
    else { // if(cell == self.cellWordCount) {
        [self refreshGenerated];
    }
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
                 Settings.sharedInstance.passwordGenerationConfig = self.config;
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
                 Settings.sharedInstance.passwordGenerationConfig = self.config;
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
                 Settings.sharedInstance.passwordGenerationConfig = self.config;
                 [self bindUi];
                 [self refreshGenerated];
             }];
}

- (void)changeWordLists {
    NSArray<NSString*> *sortedKeys = [PasswordGenerationConfig.wordLists.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* v1 = PasswordGenerationConfig.wordLists[obj1];
        NSString* v2 = PasswordGenerationConfig.wordLists[obj2];
        
        return finderStringCompare(v1, v2);
    }];
    
    NSArray* friendlySortedNames = [sortedKeys map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return PasswordGenerationConfig.wordLists[obj];
    }];
    
    NSMutableIndexSet* sel = [NSMutableIndexSet indexSet];
    for(int i=0;i<sortedKeys.count;i++) {
        if([self.config.wordLists containsObject:sortedKeys[i]]) {
            [sel addIndex:i];
        }
    }
    
    [self promptForItems:NSLocalizedString(@"password_gen_vc_select_wordlists", @"Select Word Lists")
                 options:friendlySortedNames
         selectedIndices:sel
              completion:^(NSIndexSet *selected) {
                  NSMutableArray<NSString*>* selectedKeys = @[].mutableCopy;
                  [selected enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
                      [selectedKeys addObject:sortedKeys[idx]];
                  }];
                  self.config.wordLists = selectedKeys;
                  Settings.sharedInstance.passwordGenerationConfig = self.config;
                  [self bindUi];
                  [self refreshGenerated];
              }];
}

- (void)changeCharacterGroups {
    NSArray<NSNumber*>* pools = @[    @(kPasswordGenerationCharacterPoolUpper),
                                      @(kPasswordGenerationCharacterPoolLower),
                                      @(kPasswordGenerationCharacterPoolNumeric),
                                      @(kPasswordGenerationCharacterPoolSymbols)];
    
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
                  Settings.sharedInstance.passwordGenerationConfig = self.config;
                  
                  [self bindUi];
                  [self refreshGenerated];
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
                                   Settings.sharedInstance.passwordGenerationConfig = self.config;
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
                                   Settings.sharedInstance.passwordGenerationConfig = self.config;
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
    
    vc.items = options;
    vc.selected = [NSIndexSet indexSetWithIndex:currentIndex];
    vc.onSelectionChanged = ^(NSIndexSet * _Nonnull selectedIndices) {
        [self.navigationController popViewControllerAnimated:YES];
        completion(selectedIndices.firstIndex);
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
    
    vc.items = options;
    vc.selected = selectedIndices;
    vc.multipleSelectMode = YES;
    vc.multipleSelectDisallowEmpty = YES;
    
    vc.onSelectionChanged = ^(NSIndexSet * _Nonnull selectedIndices) {
        completion(selectedIndices);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
