//
//  UITableViewTemp.m
//  Strongbox
//
//  Created by Strongbox on 28/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UITableView+EmptyDataSet.h"

@implementation UITableView (EmptyDataSet)

- (void)setEmptyTitle:(NSAttributedString *)title {
    [self setEmptyTitle:title description:nil];
}

- (void)setEmptyTitle:(NSAttributedString *)title description:(NSAttributedString *)description {
    [self setEmptyTitle:title description:description buttonTitle:nil buttonAction:nil];
}

- (void)setEmptyTitle:(NSAttributedString *)title
          description:(NSAttributedString *)description
          buttonTitle:(NSAttributedString *)buttonTitle
         buttonAction:(dispatch_block_t)buttonAction {
    [self setEmptyTitle:title description:description buttonTitle:buttonTitle bigBlueBounce:NO buttonAction:buttonAction];
}

- (void)setEmptyTitle:(NSAttributedString *)title
          description:(NSAttributedString *)description
          buttonTitle:(NSAttributedString *)buttonTitle
        bigBlueBounce:(BOOL)bigBlueBounce
         buttonAction:(dispatch_block_t)buttonAction {
    if (title == nil) {
        self.backgroundView = nil;
    }
    else {
        self.backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        UILabel* labelTitle = [[UILabel alloc] init];
        labelTitle.attributedText = title;
        labelTitle.numberOfLines = 1;
        labelTitle.textAlignment = NSTextAlignmentCenter;
        
        UIStackView* stackView = [[UIStackView alloc] initWithArrangedSubviews:@[labelTitle]];

        stackView.spacing = 4;
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.alignment = UIStackViewAlignmentCenter;
        stackView.distribution = UIStackViewDistributionFill;
        stackView.layoutMarginsRelativeArrangement = YES;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel* labelDescription;
        if (description) {
            labelDescription = [[UILabel alloc] init];
            labelDescription.attributedText = description;
            labelDescription.numberOfLines = 0;
            labelDescription.textAlignment = NSTextAlignmentCenter;
            
            [stackView addArrangedSubview:labelDescription];
        }
        
        if (buttonTitle) {
            UIButton* button = [[UIButton alloc] init];
            
            [button setAttributedTitle:buttonTitle forState:UIControlStateNormal];
            
            [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
                buttonAction();
            }] forControlEvents:UIControlEventTouchUpInside];
            
            [stackView addArrangedSubview:button];

            if ( bigBlueBounce ) {
                button.backgroundColor = UIColor.systemBlueColor;
                button.layer.cornerRadius = 5.0;
                
                NSLayoutConstraint *widthContraints = [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:200];
                
                NSLayoutConstraint *heightContraints = [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:45];
                
                [NSLayoutConstraint activateConstraints:@[heightContraints,widthContraints]];

                [stackView setCustomSpacing:24 afterView:labelDescription ? labelDescription : labelTitle];

                [self bounce:button];
            }
        }
        
        [self.backgroundView addSubview:stackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [stackView.centerXAnchor constraintEqualToAnchor:self.backgroundView.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:self.backgroundView.centerYAnchor constant:0],
            
            [stackView.leftAnchor constraintGreaterThanOrEqualToAnchor:self.backgroundView.leftAnchor constant:20],
            [stackView.rightAnchor constraintGreaterThanOrEqualToAnchor:self.backgroundView.rightAnchor constant:20],
            
            [labelTitle.leftAnchor constraintGreaterThanOrEqualToAnchor:stackView.leftAnchor constant:0],
            [labelTitle.rightAnchor constraintGreaterThanOrEqualToAnchor:stackView.rightAnchor constant:0],
        ]];
    }
}

- (void)bounce:(UIButton*)yourButton {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform"];
    
    CGFloat bounceDuration = 0.30f;
    
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.duration = bounceDuration;
    anim.repeatCount = 3.0f;
    anim.autoreverses = YES;
    anim.removedOnCompletion = YES;
    anim.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(1.06, 1.05, 1.0)];
    
    
    CAAnimationGroup* group = [CAAnimationGroup new];
    group.animations = @[anim];
    group.duration = bounceDuration + 3.0f;
    group.repeatCount = INFINITY;
    
    [yourButton.layer addAnimation:group forKey:nil];
}

@end
