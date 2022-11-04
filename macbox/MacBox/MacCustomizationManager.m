//
//  CustomizationManager.m
//  MacBox
//
//  Created by Strongbox on 13/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "MacCustomizationManager.h"
#import "Settings.h"
#import "Utils.h"
#import "Constants.h"

#import "Strongbox-Swift.h"

@implementation MacCustomizationManager

+ (void)applyCustomizations {
    if ( [self isAProBundle] ) {
        NSLog(@"Pro Bundle... customizing...");
        [Settings.sharedInstance setPro:YES];
    }
}

+ (BOOL)isUnifiedBundle {
    return MacCustomizationManager.isUnifiedFreemiumBundle || MacCustomizationManager.isUnifiedProBundle;
}

+ (BOOL)isUnifiedProBundle {
    return StrongboxProductBundle.isUnifiedProBundle;
}

+ (BOOL)isAProBundle {
    return StrongboxProductBundle.isAProBundle;
}

+ (BOOL)isUnifiedFreemiumBundle {
    return StrongboxProductBundle.isUnifiedFreemiumBundle;
}

@end
