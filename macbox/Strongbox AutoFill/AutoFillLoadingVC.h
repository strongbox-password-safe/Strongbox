//
//  AutoFillLoadingVC.h
//  MacBox
//
//  Created by Strongbox on 28/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillLoadingVC : NSViewController

@property (nonatomic, copy) void (^onCancelButton)(void); 

@end

NS_ASSUME_NONNULL_END
