//
//  KSPasswordField.h
//  Sandvox
//
//  Created by Mike Abdullah on 28/04/2012.
//  Copyright (c) 2012-2014 Karelia Software. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Cocoa/Cocoa.h>

@interface KSPasswordField : NSSecureTextField <NSTextViewDelegate>
{
  @private
    BOOL    _showsText;
    BOOL    _becomesFirstResponderWhenToggled;
    NSUInteger _length;
    
}

/**
 Whether to display the password as plain text or not.
 */
@property(nonatomic) BOOL showsText;
@property (nonatomic, assign) NSUInteger length;

/**
 Whether the receiver becomes first responder whenever `.showsText` changes.
 
 The default is `YES`, which means that whenever the password is shown or hidden,
 the field will try to become the first responder, ready for the user to type
 into it. Set to `NO` if you want to perform your own management of the first
 responder instead.
 */
@property(nonatomic) BOOL becomesFirstResponderWhenToggled;

/**
 Sets `.showsText` to `YES`.
 
 Convenient for connecting up a "Show Password" button.
 */
- (IBAction)showText:(id)sender;

/**
 Sets `.showsText` to `NO`.
 
 Convenient for connecting up a "Hide Password" button.
 */
- (IBAction)secureText:(id)sender;

/**
 Toggles the value of `.showsText`.
 
 Generally connected up as the action of a "Show Password" checkbox, or some
 kind of toggle button.
 */
- (IBAction)toggleTextShown:(id)sender;

@end


@interface KSPasswordTextFieldCell : NSTextFieldCell
@end

@interface KSPasswordSecureTextFieldCell : NSSecureTextFieldCell
@end
