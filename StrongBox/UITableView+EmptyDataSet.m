//
//  UITableViewTemp.m
//  Strongbox
//
//  Created by Strongbox on 28/10/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "UITableView+EmptyDataSet.h"
#import <objc/runtime.h>

@interface ClosureSleeve ()

@property (copy) dispatch_block_t action;

@end

@implementation ClosureSleeve
    
- (instancetype)initWithAction:(dispatch_block_t)action {
    self = [super init];
    if (self) {
        self.action = action;
    }
    return self;
}

- (void)act {
    if (self.action) {
        self.action();
    }
    else {
        NSLog(@"WARNWARN: No action set on Closure Sleeve!");
    }
}

@end

@implementation UITableView (EmptyDataSet)

- (void)setEmptyTitle:(NSAttributedString *)title {
    [self setEmptyTitle:title description:nil];
}

- (void)setEmptyTitle:(NSAttributedString *)title description:(NSAttributedString *)description {
    [self setEmptyTitle:title description:description buttonTitle:nil buttonAction:nil];
}

- (void)setEmptyTitle:(NSAttributedString *)title description:(NSAttributedString *)description buttonTitle:(NSAttributedString *)buttonTitle buttonAction:(dispatch_block_t)buttonAction {
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

        stackView.spacing = 8;
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
            
            if (@available(iOS 14.0, *)) {
                [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
                    buttonAction();
                }] forControlEvents:UIControlEventTouchUpInside];
            }
            else {
                ClosureSleeve* sleeve = [[ClosureSleeve alloc] initWithAction:buttonAction];
                [button addTarget:sleeve action:@selector(act) forControlEvents:UIControlEventTouchUpInside];
                
                // Funky trick to keep the closure around for the lifetime of the button... :(
                objc_setAssociatedObject (button, [NSUUID.UUID.UUIDString cStringUsingEncoding:NSUTF8StringEncoding], sleeve, OBJC_ASSOCIATION_RETAIN);
            }
            
            [stackView addArrangedSubview:button];
        }
        
        [self.backgroundView addSubview:stackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [stackView.centerXAnchor constraintEqualToAnchor:self.backgroundView.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:self.backgroundView.centerYAnchor],
            [stackView.leftAnchor constraintGreaterThanOrEqualToAnchor:self.backgroundView.leftAnchor constant:20],
            [stackView.rightAnchor constraintGreaterThanOrEqualToAnchor:self.backgroundView.rightAnchor constant:20],
            
            [labelTitle.leftAnchor constraintGreaterThanOrEqualToAnchor:stackView.leftAnchor constant:0],
            [labelTitle.rightAnchor constraintGreaterThanOrEqualToAnchor:stackView.rightAnchor constant:0],
        ]];
    }
}

- (void)blah {
    NSLog(@"Blah!");
}

@end
