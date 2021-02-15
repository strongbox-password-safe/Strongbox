//
//  CustomFieldEditorControllerViewController.h
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CustomFieldViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface CustomFieldEditorViewController : UIViewController

@property (nullable) CustomFieldViewModel* customField;
@property (nonatomic, copy, nullable) void (^onDone)(CustomFieldViewModel* field);
@property NSSet<NSString*> *customFieldsKeySet;
@property BOOL colorizeValue;

@end

NS_ASSUME_NONNULL_END
