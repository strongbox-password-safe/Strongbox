//
//  InitialViewController.h
//  Strongbox-iOS
//
//  Created by Mark on 06/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface InitialViewController : UITabBarController

- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL;

@end

NS_ASSUME_NONNULL_END
