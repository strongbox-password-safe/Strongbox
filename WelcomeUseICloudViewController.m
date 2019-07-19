//
//  WelcomeUseICloudViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 17/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "WelcomeUseICloudViewController.h"
#import "WelcomeCreateDatabaseViewController.h"
#import "Settings.h"
#import "SafesList.h"

@interface WelcomeUseICloudViewController ()

@end

@implementation WelcomeUseICloudViewController

- (IBAction)onUseICloud:(id)sender {
    [self enableICloudAndContinue:YES];
}

- (IBAction)onDoNotUseICloud:(id)sender {
    [self enableICloudAndContinue:NO];
}

- (void)enableICloudAndContinue:(BOOL)enable {
    Settings.sharedInstance.iCloudPrompted = YES;
    Settings.sharedInstance.iCloudOn = enable;
    
    if(self.addExisting) {
        NSInteger count = SafesList.sharedInstance.snapshot.count;
        self.onDone(count == 0, nil);
    }
    else {
        [self performSegueWithIdentifier:@"segueToDatabaseName" sender:nil];
    }
}


- (IBAction)onDismiss:(id)sender {
    self.onDone(NO, nil);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToDatabaseName"]) {
        WelcomeCreateDatabaseViewController* vc = (WelcomeCreateDatabaseViewController*)segue.destinationViewController;
        
        vc.onDone = self.onDone;
    }
}

@end
