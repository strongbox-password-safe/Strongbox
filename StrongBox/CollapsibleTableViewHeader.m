//
//  CollapsibleTableViewHeader.m
//  Strongbox-iOS
//
//  Created by Mark on 01/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CollapsibleTableViewHeader.h"

@interface CollapsibleTableViewHeader ()

@property UILabel* titleLabel;
@property UILabel* arrowLabel;

@end

@implementation CollapsibleTableViewHeader

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        self.titleLabel = [[UILabel alloc] init];
        self.arrowLabel = [[UILabel alloc] init];
        self.arrowLabel.text = @">";

        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.arrowLabel];
    
        UITapGestureRecognizer *headerTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sectionHeaderWasTouched:)];
        
        [self addGestureRecognizer:headerTapGesture];
        
        [self.arrowLabel.widthAnchor constraintEqualToConstant:12].active = YES;
        [self.arrowLabel.heightAnchor constraintEqualToConstant:12].active = YES;
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.arrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSDictionary<NSString*, id>* views = @{ @"titleLabel" : self.titleLabel, @"arrowLabel" : self.arrowLabel };
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-20-[titleLabel]-[arrowLabel]-20-|"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[titleLabel]-|"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:views]];

    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[arrowLabel]-|"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:views]];
}

- (void)sectionHeaderWasTouched:(id)sender {
    if(self.onToggleSection) {
        self.onToggleSection();
    }
}

- (void)setCollapsed:(BOOL)collapsed {
    [self.arrowLabel setTransform:CGAffineTransformMakeRotation(collapsed ? 0.0 : M_PI / 2)];

}

@end
