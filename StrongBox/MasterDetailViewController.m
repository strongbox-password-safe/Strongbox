//
//  MasterDetailViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 04/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MasterDetailViewController.h"
#import <ISMessages/ISMessages.h>
#import "BrowseSafeView.h"

@interface MasterDetailViewController () <UISplitViewControllerDelegate>

@end

@implementation MasterDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
    self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
    
//    [self listenToNotifications];
}

//- (NSArray<UIKeyCommand *> *)keyCommands {
//    return @[[UIKeyCommand commandWithTitle:@"Find"
//                                      image:nil
//                                     action:@selector(onFind:)
//                                      input:@"f"
//                              modifierFlags:UIKeyModifierCommand
//                               propertyList:nil]];
//}
//
//- (void)onFind:(id)param {
//    NSLog(@"onFind - [%@]", param);
//}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    return YES;
}

- (void)onClose {
//    [self unListenToNotifications];
    
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
