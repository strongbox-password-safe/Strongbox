//
//  CollapsibleTableViewHeader.m
//  Strongbox-iOS
//
//  Created by Mark on 01/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CollapsibleTableViewHeader.h"
#import "Utils.h"

@interface CollapsibleTableViewHeader ()

@property UILabel* titleLabel;
@property UIButton* button1;
@property UIButton* toggleCollapseButton;
@property (nonatomic, copy) void (^onCopyButton)(void);

@end

@implementation CollapsibleTableViewHeader

- (void)addTopBorderWithColor:(UIColor *)color andWidth:(CGFloat) borderWidth {
    UIView *border = [UIView new];
    border.backgroundColor = color;
    [border setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin];
    border.frame = CGRectMake(0, 0, self.frame.size.width, borderWidth);
    [self addSubview:border];
}

- (void)addBottomBorderWithColor:(UIColor *)color andWidth:(CGFloat) borderWidth {
    UIView *border = [UIView new];
    border.backgroundColor = color;
    [border setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    border.frame = CGRectMake(0, self.frame.size.height - borderWidth, self.frame.size.width, borderWidth);
    [self addSubview:border];
}

- (instancetype)initWithOnCopy:(void(^)(void))onCopy {
    if (self = [super initWithFrame:CGRectZero]) {
        self.onCopyButton = onCopy;
        
        self.titleLabel = [[UILabel alloc] init];

        self.button1 = [[UIButton alloc] init];
        UIImage* image1 = [UIImage systemImageNamed:@"doc.on.doc.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
        [self.button1 setImage:image1 forState:UIControlStateNormal];
        [self.button1 addTarget:self action:@selector(onCopyButton:) forControlEvents:UIControlEventTouchUpInside];

        self.toggleCollapseButton = [[UIButton alloc] init];
        UIImage* image3 = [UIImage systemImageNamed:@"chevron.right.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
        self.toggleCollapseButton.tintColor = UIColor.secondaryLabelColor;
        
        [self.toggleCollapseButton setImage:image3 forState:UIControlStateNormal];
        
        [self.toggleCollapseButton addTarget:self action:@selector(sectionHeaderWasTouched:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.button1];
        [self.contentView addSubview:self.toggleCollapseButton];
    
        UITapGestureRecognizer *headerTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sectionHeaderWasTouched:)];
        
        [self addGestureRecognizer:headerTapGesture];
    
        [self.contentView.heightAnchor constraintEqualToConstant:48].active = YES;
        
        if ( onCopy ) {
            [self.button1.widthAnchor constraintEqualToConstant:32].active = YES;
            [self.button1.heightAnchor constraintEqualToConstant:32].active = YES;
        }
        else {
            [self.button1.widthAnchor constraintEqualToConstant:0].active = YES;
            [self.button1.heightAnchor constraintEqualToConstant:0].active = YES;
        }

        [self.toggleCollapseButton.widthAnchor constraintEqualToConstant:32].active = YES;
        [self.toggleCollapseButton.heightAnchor constraintEqualToConstant:32].active = YES;
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.button1.translatesAutoresizingMaskIntoConstraints = NO;
        self.toggleCollapseButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        self.layer.backgroundColor = dark ? ColorFromRGB(0x0d1117).CGColor : ColorFromRGB(0xf6f8fa).CGColor;

        
        [self addBottomBorderWithColor:UIColor.systemBackgroundColor andWidth:1.0f];
        [self addTopBorderWithColor:UIColor.systemBackgroundColor andWidth:1.0f];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self removeAllConstraints];

    [self.contentView.heightAnchor constraintEqualToConstant:48].active = YES;

    NSDictionary<NSString*, id>* views = @{ @"titleLabel" : self.titleLabel,
                                            @"button1" : self.button1,
                                            @"toggleCollapseButton" : self.toggleCollapseButton,
                                            @"superview" : self.contentView };
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-20-[titleLabel]-[button1]-20-[toggleCollapseButton]-20-|"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[superview]-(<=1)-[titleLabel]"
                                                                             options:NSLayoutFormatAlignAllCenterY
                                                                             metrics:nil
                                                                               views:views]];
    
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[superview]-(<=1)-[button1]"
                                                                             options:NSLayoutFormatAlignAllCenterY
                                                                             metrics:nil
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[superview]-(<=1)-[toggleCollapseButton]"
                                                                             options:NSLayoutFormatAlignAllCenterY
                                                                             metrics:nil
                                                                               views:views]];
}

- (void)removeAllConstraints {
    for (NSLayoutConstraint *c in self.contentView.constraints ) {
        [self.contentView removeConstraint:c];
    }
}

- (void)sectionHeaderWasTouched:(id)sender {
    if(self.onToggleSection) {
        self.onToggleSection();
    }
}

- (void)onCopyButton:(id)sender {
    if(self.onCopyButton) {
        self.onCopyButton();
    }
}

- (void)setCollapsed:(BOOL)collapsed {
    [self.toggleCollapseButton setTransform:CGAffineTransformMakeRotation(collapsed ? 0.0 : M_PI / 2)];

}

@end
