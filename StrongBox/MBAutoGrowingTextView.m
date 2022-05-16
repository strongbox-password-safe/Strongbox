//
//  TINAutoGrowingTextView.m
//  TINUIKit
//
//  Created by Matej Balantic on 14/05/14.
//  Copyright (c) 2014 Matej Balantič. All rights reserved.
//

#import "MBAutoGrowingTextView.h"

@interface MBAutoGrowingTextView ()

@property (nonatomic, weak) NSLayoutConstraint *heightConstraint;
@property (nonatomic, weak) NSLayoutConstraint *minHeightConstraint;
@property (nonatomic, weak) NSLayoutConstraint *maxHeightConstraint;

@property (nonatomic) BOOL layoutSubviewsCrashAvoidanceHack;

@end

@implementation MBAutoGrowingTextView

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self associateConstraints];
    }
    
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self associateConstraints];
    }
    return self;
}

-(void)associateConstraints {
    
    
    
    for (NSLayoutConstraint *constraint in self.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeHeight) {
            
            if (constraint.relation == NSLayoutRelationEqual) {
                self.heightConstraint = constraint;
            }
            
            else if (constraint.relation == NSLayoutRelationLessThanOrEqual) {
                self.maxHeightConstraint = constraint;
            }
            
            else if (constraint.relation == NSLayoutRelationGreaterThanOrEqual) {
                self.minHeightConstraint = constraint;
            }
        }
    }
}

- (void)layoutSubviews {
    
    
    
    
    if(self.layoutSubviewsCrashAvoidanceHack){
           return;
    }
    self.layoutSubviewsCrashAvoidanceHack = YES;
    
    [super layoutSubviews];
    
    
    NSAssert(self.heightConstraint != nil, @"Unable to find height auto-layout constraint. MBAutoGrowingTextView\
             needs a Auto-layout environment to function. Make sure you are using Auto Layout and that UITextView is enclosed in\
             a view with valid auto-layout constraints.");
    
    
    CGSize sizeThatFits = [self sizeThatFits:self.frame.size];
    float newHeight = sizeThatFits.height * 1.2; 

    
    if (self.maxHeightConstraint) {
        newHeight = MIN(newHeight, self.maxHeightConstraint.constant);
    }

    
    if (self.minHeightConstraint) {
        newHeight = MAX(newHeight, self.minHeightConstraint.constant);
    }
    
    
    self.heightConstraint.constant = newHeight;
    
    self.layoutSubviewsCrashAvoidanceHack = NO;
}

@end
