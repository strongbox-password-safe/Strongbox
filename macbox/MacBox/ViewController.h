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
- (Node*)getCurrentSelectedItem;
- (NSArray<Node*>*)getSelectedItems;

- (void)closeAllDetailsWindows:(void (^ _Nullable)(void))completion;
- (void)stopObservingModelAndCleanup;

@end

NS_ASSUME_NONNULL_END
