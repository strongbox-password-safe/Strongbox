//
//  UpgradeQuestionsViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 14/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UpgradeQuestionsViewController.h"
#import "UpgradeAnswerViewController.h"

@interface UpgradeQuestionsViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *cellFreeAndProDifferences;
@property (weak, nonatomic) IBOutlet UITableViewCell *cellWhatHappensAtEndOfProTrial;
@property (weak, nonatomic) IBOutlet UITableViewCell *canIJustUseFreeVersionForever;
@property (weak, nonatomic) IBOutlet UITableViewCell *anotherQuestion;
@property (weak, nonatomic) IBOutlet UITableViewCell *workOnMyOtherIOsDevices;
@property (weak, nonatomic) IBOutlet UITableViewCell *shareUpgradeWithFamilyFriends;
@property (weak, nonatomic) IBOutlet UITableViewCell *worksOnMac;
@property (weak, nonatomic) IBOutlet UITableViewCell *buyLicensesForCompany;

@end

@implementation UpgradeQuestionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = UIView.new;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    NSString* question = cell.textLabel.text;

    NSString* answer = [self getAnswerForQuestionCell:cell];
    
    [self performSegueWithIdentifier:@"segueToAnswer" sender: @{ question : answer }];
    		
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString*)getAnswerForQuestionCell:(UITableViewCell*)cell {
    if (cell == self.cellFreeAndProDifferences) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_free_pro_differences", @"");
        return loc;
    }
    else if (cell == self.cellWhatHappensAtEndOfProTrial) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_end_trial", @"");
        return loc;
    }
    else if (cell == self.canIJustUseFreeVersionForever) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_free_version_forever", @"");
        return loc;
    }
    else if (cell == self.anotherQuestion) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_another_question", @"");
        return loc;
    }
    else if (cell == self.workOnMyOtherIOsDevices) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_works_on_other_devices", @"");
        return loc;
    }
    else if (cell == self.shareUpgradeWithFamilyFriends) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_share_family", @"");
        return loc;
    }
    else if (cell == self.worksOnMac) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_works_on_mac", @"");
        return loc;
    }
    else if (cell == self.buyLicensesForCompany) {
        NSString* loc = NSLocalizedString(@"upgrade_question_answer_buy_company_licenses", @"");
        return loc;
    }
    else {
        return @"N/A";
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSDictionary *dict = sender;
    NSString* question = dict.allKeys.firstObject;
    NSString* answer = dict[question];
    
    UpgradeAnswerViewController* vc = segue.destinationViewController;
    vc.question = question;
    vc.answer = answer;
}

- (IBAction)onDone:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
