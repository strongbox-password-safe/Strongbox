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

@interface PasswordGenerationViewController ()

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

@end

@implementation PasswordGenerationViewController

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(!self.config) {
        self.config = [PasswordGenerationConfig defaults];
    }
    else {
//        self.config = [self.config clone]; // TODO: So we don't interfere if cancelled - make a working copy
    }
    
    [self bindBasicLengthSlider];
    [self bindTableView];
    
    [self refreshGenerated];
}

- (IBAction)onBasicLengthChanged:(id)sender {
    UISlider* slider = (UISlider*)sender;
    self.config.basicLength = (NSInteger)slider.value;
    
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
    
    return str ? str : @"<Generation Failed>";
}
    
- (void)bindTableView {
    self.cellAlgorithm.detailTextLabel.text = self.config.algorithm == kPasswordGenerationAlgorithmBasic ? @"Basic" : @"Diceware (XKCD)";
    
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
    
    [self reloadDataAnimated:YES];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if(cell == self.cellAlgorithm) {
        [self promptForItem:@"Select Algorithm"
                    options:@[@"Basic", @"Diceware (XKCD)"]
               currentIndex:self.config.algorithm == kPasswordGenerationAlgorithmBasic ? 0 : 1
                 completion:^(BOOL success, NSInteger selected) {
                     if(success) {
                         self.config.algorithm = selected == 0 ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;
                         [self bindTableView];
                     }
                 }];
    }
    else {
        [self refreshGenerated];
    }
}

- (void)promptForItem:(NSString*)title
              options:(NSArray<NSString*>*)options
         currentIndex:(NSInteger)currentIndex
           completion:(void(^)(BOOL success, NSInteger selected))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = options;
    vc.currentlySelectedIndex = currentIndex;
    vc.onDone = ^(BOOL success, NSInteger selectedIndex) {
        [self.navigationController popViewControllerAnimated:YES];
        completion(success, selectedIndex);
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)promptForItems:(NSString*)title
               options:(NSArray<NSString*>*)options
       selectedIndices:(NSIndexSet*)selectedIndices
            completion:(void(^)(BOOL success, NSIndexSet* selected))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    
    vc.items = options;
    vc.selectedIndices = selectedIndices;
    vc.onMultipleDone = ^(BOOL success, NSIndexSet * _Nonnull selectedIndices) {
        // TODO:
    };
    
    vc.title = title;
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
