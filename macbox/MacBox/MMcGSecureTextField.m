//
//  MMcGSecureTextField.m
//  MacBox
//
//  Created by Strongbox on 03/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//
// Inspired (heavily) by KSPasswordField and DSFSecureTextField (https://github.com/dagronf/DSFSecureTextField)
//

#import "MMcGSecureTextField.h"

@interface MMcGSecureTextFieldCell : NSTextFieldCell
@end

@interface MMcGSecureSecureTextFieldCell : NSSecureTextFieldCell
@end

@interface MMcGSecureTextField ()

@property NSButton* buttonRevealConceal;
@property BOOL innerConcealed;

@end

@implementation MMcGSecureTextField

+ (Class)cellClass {
    return [NSSecureTextFieldCell class];
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self addRevealConcealButton];
        self.concealed = YES;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ( self = [super initWithCoder:aDecoder] ) {
        [self addRevealConcealButton];
        self.concealed = YES;
    }
    
    return self;
}

- (void)bindRevealConcealButtonImage{
    if ( !self.concealed ) {
        self.buttonRevealConceal.image = [NSImage imageWithSystemSymbolName:@"eye.slash" accessibilityDescription:nil];
        self.buttonRevealConceal.symbolConfiguration = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge];
        self.buttonRevealConceal.contentTintColor = NSColor.systemOrangeColor;
    }
    else {
        self.buttonRevealConceal.image = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:nil];
        self.buttonRevealConceal.symbolConfiguration = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge];
        self.buttonRevealConceal.contentTintColor = nil;
    }
}

- (void)addRevealConcealButton {
    self.buttonRevealConceal = [[NSButton alloc] init];
    
    self.buttonRevealConceal.bezelStyle = NSBezelStyleSmallSquare;
    self.buttonRevealConceal.wantsLayer = YES;
    self.buttonRevealConceal.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.buttonRevealConceal.bordered = NO;
    self.buttonRevealConceal.action = @selector(toggleConcealed:);
    self.buttonRevealConceal.target = self;
    self.buttonRevealConceal.imagePosition = NSImageLeading;
    self.buttonRevealConceal.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    self.buttonRevealConceal.keyEquivalent = @"r";
    self.buttonRevealConceal.title = @"";
    self.buttonRevealConceal.toolTip = NSLocalizedString(@"secure_text_field_conceal_reveal_tooltip", @"Reveal or Conceal (⌘R to Toggle)");
    [self bindRevealConcealButtonImage];
    
    self.buttonRevealConceal.translatesAutoresizingMaskIntoConstraints = NO;
    
    CGFloat height, trailingOffset;
    
    height = self.frame.size.height;
    trailingOffset = -4.0;
    
    [self.buttonRevealConceal addConstraint:[NSLayoutConstraint constraintWithItem:self.buttonRevealConceal attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height]];
    
    [self addSubview:self.buttonRevealConceal];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.buttonRevealConceal attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.buttonRevealConceal attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1 constant:trailingOffset]];
    
    self.buttonRevealConceal.needsLayout = YES;
    self.needsUpdateConstraints = YES;
    
    [self.window recalculateKeyViewLoop];
}

- (BOOL)concealed {
    return self.innerConcealed;
}

- (void)setConcealed:(BOOL)concealed {
    self.innerConcealed = concealed;
    
    [self swapCellForOneOfClass:(!concealed ? [MMcGSecureTextFieldCell class] : [MMcGSecureSecureTextFieldCell class])];
    [self bindRevealConcealButtonImage];
}

- (IBAction)toggleConcealed:(id)sender {
    self.concealed = !self.concealed;
}

- (void)swapCellForOneOfClass:(Class)cellClass {
    
    
    NSValue *selection = [[self currentEditor] valueForKey:@"selectedRange"];
    
    
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [[self cell] encodeWithCoder:archiver];
    [archiver finishEncoding];
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    NSTextFieldCell *cell = [[cellClass alloc] initWithCoder:unarchiver];
    cell.stringValue = [self.cell stringValue]; 
    [unarchiver finishDecoding];
    
    [self setCell:cell];
    [self setNeedsDisplay:YES];

    
    if (selection) {
        [self.window makeFirstResponder:self];
        [[self currentEditor] setSelectedRange:[selection rangeValue]];
    }
    else if ( (YES) ) { 
        NSTextView *fieldEditor = (NSTextView *)[self.window firstResponder];
        BOOL isEditingPassword = [fieldEditor isKindOfClass:[NSTextView class]] && [fieldEditor.delegate isKindOfClass:[MMcGSecureTextField class]];

        if (isEditingPassword) {
            [self.window makeFirstResponder:self];
        }
    }
}

- (void)textDidChange:(NSNotification *)aNotification {
    
    
    
    
    NSNotification *newNotif = [NSNotification notificationWithName:NSControlTextDidChangeNotification
                                                             object:self
                                                           userInfo: @{
                                                                        @"NSFieldEditor" : [self.window fieldEditor:NO forObject:self]
                                                                     }];
        
    [[NSNotificationCenter defaultCenter] postNotification:newNotif];
}

@end





@implementation MMcGSecureTextFieldCell

- (void)selectWithFrame:(NSRect)rect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)delegate start:(NSInteger)selStart length:(NSInteger)selLength {
    
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;
    
    [super selectWithFrame:newRect inView:controlView editor:textObj delegate:delegate start:selStart length:selLength];
}

- (void)editWithFrame:(NSRect)rect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)delegate event:(NSEvent *)event {
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;

    [super editWithFrame:newRect inView:controlView editor:textObj delegate:delegate event:event];
}

- (void)drawInteriorWithFrame:(NSRect)rect inView:(NSView *)controlView {
    if ( self.drawsBackground ) {
        [NSColor.controlBackgroundColor setFill];
        NSRectFill(rect);
    }
    
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;

    [super drawInteriorWithFrame:newRect inView:controlView];
}

@end

@implementation MMcGSecureSecureTextFieldCell

- (void)selectWithFrame:(NSRect)rect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)delegate start:(NSInteger)selStart length:(NSInteger)selLength {
    
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;
    
    [super selectWithFrame:newRect inView:controlView editor:textObj delegate:delegate start:selStart length:selLength];
}

- (void)editWithFrame:(NSRect)rect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)delegate event:(NSEvent *)event {
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;

    [super editWithFrame:newRect inView:controlView editor:textObj delegate:delegate event:event];
}

- (void)drawInteriorWithFrame:(NSRect)rect inView:(NSView *)controlView {
    if ( self.drawsBackground ) {
        [NSColor.controlBackgroundColor setFill];
        NSRectFill(rect);
    }
    
    NSRect newRect = rect;
    newRect.size.width -= rect.size.height;

    [super drawInteriorWithFrame:newRect inView:controlView];
}

@end
