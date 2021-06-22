//
//  ViewController.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"
#import "CustomPasswordTextField.h"
#import "AttachmentCollectionView.h"
#import <QuickLook/QuickLook.h>
#import <Quartz/Quartz.h>
#import "ClickableImageView.h"
#import "KSPasswordField.h"

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : NSViewController

- (void)onDocumentLoaded; 

@end

NS_ASSUME_NONNULL_END
