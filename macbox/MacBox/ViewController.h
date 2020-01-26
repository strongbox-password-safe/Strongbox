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

@interface ViewController : NSViewController<   NSOutlineViewDelegate,
                                                NSOutlineViewDataSource,
                                                NSTableViewDelegate,
                                                NSTableViewDataSource>

- (void)onFileChangedByOtherApplication;

- (void)setInitialModel:(ViewModel*)model;
- (void)updateModel:(ViewModel *)model;

// Used by Node Details too...
void onSelectedNewIcon(ViewModel* model, Node* item, NSNumber* index, NSData* data, NSUUID* existingCustom, NSWindow* window);

- (void)autoPromptForTouchIdIfDesired;

@end

NS_ASSUME_NONNULL_END
