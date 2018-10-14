//
//  QuickViewController.h
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CredentialProviderViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface QuickViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *labelSafeName;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewLogo;
@property (nonatomic) CredentialProviderViewController *rootViewController;

@end

NS_ASSUME_NONNULL_END
