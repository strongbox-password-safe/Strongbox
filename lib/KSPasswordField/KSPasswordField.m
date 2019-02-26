//
//  KSPasswordField.m
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

#import "KSPasswordField.h"

#define YOFFSET 2

NSString *MyControlDidBecomeFirstResponderNotification = @"MyControlDidBecomeFirstResponderNotification";

@interface NSObject(controlDidBecomeFirstResponder)
- (void) controlDidBecomeFirstResponder:(NSNotification *)aNotification;
@end

@implementation KSPasswordTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    cellFrame.origin.y -= 1;
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end

@implementation KSPasswordSecureTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end

@implementation KSPasswordField

-(BOOL)textView:(NSTextView *)aTextView doCommandBySelector: (SEL)aSelector
{
    if (aSelector == @selector(moveDown:))
    {
        if ([self delegate] && [[self delegate] respondsToSelector:aSelector])
        {
            [((NSResponder *)[self delegate]) moveDown:self];
            return YES;
        }
    }
    return NO;
}

- (id)initWithFrame:(NSRect)frameRect;
{
    if (self = [super initWithFrame:frameRect])
    {
        _becomesFirstResponderWhenToggled = YES;

		// Don't show text by default. This needs to be called to replace the standard cell with our custom one.
		[self setShowsText:NO];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if (self = [super initWithCoder:aDecoder])
    {
        _becomesFirstResponderWhenToggled = YES;

		// Don't show text by default. This needs to be called to replace the standard cell with our custom one.
		[self setShowsText:NO];
    }
    return self;
}

@synthesize length = _length;

+ (Class)cellClass;
{
    return [NSSecureTextFieldCell class];       // Really just a guess; set to the right subclass from code later.
}

- (BOOL)becomeFirstResponder;
{
    // If the control's delegate responds to controlDidBecomeFirstResponder, invoke it. Also post a notification.
    BOOL didBecomeFirstResponder = [super becomeFirstResponder];
    NSNotification *notification = [NSNotification notificationWithName:MyControlDidBecomeFirstResponderNotification object:self];
    if ( [self delegate] && [[self delegate] respondsToSelector:@selector(controlDidBecomeFirstResponder:)] ) {
        [((NSObject *)[self delegate]) controlDidBecomeFirstResponder:notification];
    }
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    return didBecomeFirstResponder;
}

#pragma mark Showing Password

@synthesize showsText = _showsText;
- (void)setShowsText:(BOOL)showsText;
{
    _showsText = showsText;
    [self swapCellForOneOfClass:(showsText ? [KSPasswordTextFieldCell class] : [KSPasswordSecureTextFieldCell class])];
}

@synthesize becomesFirstResponderWhenToggled = _becomesFirstResponderWhenToggled;

- (void)showText:(id)sender;
{
    [self setShowsText:YES];
}

- (void)secureText:(id)sender;
{
    [self setShowsText:NO];
}

- (IBAction)toggleTextShown:(id)sender;
{
    [self setShowsText:![self showsText]];
}

- (void)swapCellForOneOfClass:(Class)cellClass;
{
    // Rememeber current selection for restoration after the swap
    // -valueForKey: neatly gives nil if no currently selected
    NSValue *selection = [[self currentEditor] valueForKey:@"selectedRange"];
    
    // Seems to me the best way to ensure all properties come along for the ride (e.g. border/editability) is to archive the existing cell
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [[self cell] encodeWithCoder:archiver];
    [archiver finishEncoding];
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    NSTextFieldCell *cell = [[cellClass alloc] initWithCoder:unarchiver];
    cell.stringValue = [self.cell stringValue]; // restore value; secure text fields wisely don't encode it
    [unarchiver finishDecoding];
    
    [self setCell:cell];
    [self setNeedsDisplay:YES];

    // Restore selection
    if (selection)
    {
        [self.window makeFirstResponder:self];
        [[self currentEditor] setSelectedRange:[selection rangeValue]];
    }
    else if (self.becomesFirstResponderWhenToggled)
    {
        NSTextView *fieldEditor = (NSTextView *)[self.window firstResponder];
        BOOL isEditingPassword = [fieldEditor isKindOfClass:[NSTextView class]] && [fieldEditor.delegate isKindOfClass:[KSPasswordField class]];

        if (isEditingPassword)
        {
            [self.window makeFirstResponder:self];
        }
    }
}

- (void)textDidChange:(NSNotification *)aNotification
{
    // Password fields don't seem to send out continuous binding updates, nor NSControlTextDidChangeNotification.
    // https://developer.apple.com/library/mac/documentation/cocoa/reference/applicationkit/classes/NSControl_Class/Reference/Reference.html#//apple_ref/c/data/NSControlTextDidChangeNotification
    // So we're doing that manually.
    
    NSNotification *newNotif = [NSNotification notificationWithName:NSControlTextDidChangeNotification
    object:self
    userInfo: @{ @"NSFieldEditor" : [self.window fieldEditor:NO forObject:self] }
        ];
    [[NSNotificationCenter defaultCenter] postNotification:newNotif];
}


@end
