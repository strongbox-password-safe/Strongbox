//
//  CustomNavigationItemTitleView.m
//  Strongbox-iOS
//
//  Created by Mark on 24/02/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CustomNavigationItemTitleView.h"

@implementation CustomNavigationItemTitleView

- (CGSize)intrinsicContentSize {
    // Allows us to fill the Title bar with our custom view on iOS11+
    // Do not under any circumstances remove/play with this Mark... way too much work figuring this out
    // Required to allow taps in title area also!
    return UILayoutFittingExpandedSize;
}

@end
