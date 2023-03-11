//
//  CustomizationManager.h
//  Strongbox
//
//  Created by Strongbox on 03/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomizationManager : NSObject

+ (void)applyCustomizations;

@property (readonly, class) BOOL isAProBundle;


@end

NS_ASSUME_NONNULL_END
