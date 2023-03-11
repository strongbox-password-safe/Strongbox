//
//  CustomizationManager.h
//  MacBox
//
//  Created by Strongbox on 13/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MacCustomizationManager : NSObject

+ (void)applyCustomizations;

@property (readonly, class) BOOL isAProBundle;

@property (readonly, class) BOOL isUnifiedFreemiumBundle;

@property (readonly, class) BOOL supportsTipJar;
@end

NS_ASSUME_NONNULL_END

