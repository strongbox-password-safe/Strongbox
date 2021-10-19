//
//  MarkdownCell.m
//  Strongbox
//
//  Created by Strongbox on 27/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MarkdownCell.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface MarkdownCell ()

@property SBDownTextView* downTextView;
@property NSLayoutConstraint *heightConstraint;
@property UITapGestureRecognizer *doubleTap;

@end

@implementation MarkdownCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.downTextView = [[SBDownTextView alloc] initWithFrame:CGRectZero];
    self.downTextView.editable = NO;
    self.downTextView.scrollEnabled = NO;
    self.downTextView.markdownEnabled = YES;
    
    [self addSubview:self.downTextView];

    UIView* subView = self.downTextView;
    UIView* parent = self;
    
    subView.translatesAutoresizingMaskIntoConstraints = NO;

    
    NSLayoutConstraint *trailing =[NSLayoutConstraint
                                    constraintWithItem:subView
                                    attribute:NSLayoutAttributeTrailing
                                    relatedBy:NSLayoutRelationEqual
                                    toItem:parent
                                    attribute:NSLayoutAttributeTrailingMargin
                                    multiplier:1.0f
                                    constant:0.f];

    

    NSLayoutConstraint *leading = [NSLayoutConstraint
                                       constraintWithItem:subView
                                       attribute:NSLayoutAttributeLeading
                                       relatedBy:NSLayoutRelationEqual
                                       toItem:parent
                                       attribute:NSLayoutAttributeLeadingMargin
                                       multiplier:1.0f
                                       constant:0.f];

    
    NSLayoutConstraint *top =[NSLayoutConstraint
                                     constraintWithItem:subView
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                     toItem:parent
                                     attribute:NSLayoutAttributeTopMargin
                                     multiplier:1.0f
                                     constant:0.f];
    
    
    NSLayoutConstraint *bottom =[NSLayoutConstraint
                                     constraintWithItem:subView
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                     toItem:parent
                                     attribute:NSLayoutAttributeBottomMargin
                                     multiplier:1.0f
                                     constant:0.f];

    
    
    self.heightConstraint = [NSLayoutConstraint
                                   constraintWithItem:subView
                                   attribute:NSLayoutAttributeHeight
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:nil
                                   attribute:NSLayoutAttributeNotAnAttribute
                                   multiplier:0
                                   constant:50.f];

    [parent addConstraint:trailing];
    [parent addConstraint:leading];
    [parent addConstraint:top];
    [parent addConstraint:bottom];
    [subView addConstraint:self.heightConstraint];
    
    self.doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTextViewDoubleTap:)];
    [self.doubleTap setNumberOfTapsRequired:2];
    [self.doubleTap setNumberOfTouchesRequired:1];
    [self.downTextView addGestureRecognizer:self.doubleTap];
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.downTextView.text = @"";
}

- (void)onTextViewDoubleTap:(id)sender {
    if(self.onNotesDoubleTap) {
        self.onNotesDoubleTap();
    }
}

- (void)setNotes:(NSString *)notes {
    self.downTextView.text = notes;
    
    

    CGSize sizeThatFits = [self.downTextView sizeThatFits:self.frame.size];

    float newHeight = sizeThatFits.height;



    self.heightConstraint.constant = newHeight;
}

@end
