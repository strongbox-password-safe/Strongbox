//
//  TINAutoGrowingTextView.h
//  TINUIKit
//
//  Created by Matej Balantic on 14/05/14.
//  Copyright (c) 2014 Matej Balantič. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * An auto-layout based light-weight UITextView subclass which automatically grows and shrinks
 based on the size of user input and can be constrained by maximal and minimal height - all without
 a single line of code.
 
 Made primarely for use in Interface builder and only works with Auto layout.
 
 Usage: subclass desired UITextView in IB and assign min-height and max-height constraints
 */
@interface MBAutoGrowingTextView : UITextView
@end
