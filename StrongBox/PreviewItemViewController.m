//
//  PreviewItemViewController.m
//  Strongbox
//
//  Created by Strongbox on 24/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PreviewItemViewController.h"
#import "NodeIconHelper.h"
#import "OTPToken+Generation.h"
#import "FontManager.h"
#import "MutableOrderedDictionary.h"
#import "Utils.h"

@interface PreviewItemViewController ()

@property UILabel *totpLabel;
@property OTPToken* otpToken;
@property NSTimer* timerRefreshOtp;

@property Model* model;
@property Node* item;

@end

@implementation PreviewItemViewController

+ (instancetype)forItem:(Node *)item andModel:(Model *)model {
    return [[PreviewItemViewController alloc] initForItem:item andModel:model];
}

- (instancetype)initForItem:(Node *)item andModel:(Model *)model  {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.item = item;
        self.model = model;
        
        UIImage* icon = [NodeIconHelper getIconForNode:item predefinedIconSet:model.metadata.keePassIconSet format:model.database.originalFormat];

        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.image = icon;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        UILabel *labelTitle = [[UILabel alloc] init];
        labelTitle.text = [self maybeDereference:item.title];
        labelTitle.font = FontManager.sharedInstance.title3Font;
        
        UIStackView* stackViewTitle = [[UIStackView alloc] initWithArrangedSubviews:@[imageView, labelTitle]];
        
        stackViewTitle.spacing = 8;
        stackViewTitle.axis = UILayoutConstraintAxisHorizontal;
        stackViewTitle.alignment = UIStackViewAlignmentCenter;
        stackViewTitle.distribution = UIStackViewDistributionFill; 
        stackViewTitle.layoutMarginsRelativeArrangement = YES;
        stackViewTitle.translatesAutoresizingMaskIntoConstraints = NO;

        [NSLayoutConstraint activateConstraints:@[
            [imageView.widthAnchor constraintEqualToConstant:32],
            [imageView.heightAnchor constraintEqualToConstant:32],
        ]];
        
        
        
        MutableOrderedDictionary<NSString*, NSString*> *orderedFields = [[MutableOrderedDictionary alloc] init];
        
        if (item.fields.username.length) {
            [orderedFields addKey:NSLocalizedString(@"generic_fieldname_username", @"Username") andValue:[self maybeDereference:item.fields.username]];
        }
        if (item.fields.email.length) {
            [orderedFields addKey:NSLocalizedString(@"generic_fieldname_email", @"Email") andValue:[self maybeDereference:item.fields.email]];
        }

        
        
        NSArray* sortedKeys = [item.fields.customFieldsNoEmail.allKeys sortedArrayUsingComparator:finderStringComparator];
        for(NSString* key in sortedKeys) {
            if ( ![NodeFields isTotpCustomFieldKey:key] ) {
                StringValue* sv = item.fields.customFields[key];
                NSString* derefed = [self maybeDereference:sv.value];
                
                if ( !sv.protected && derefed.length ) {
                    [orderedFields addKey:key andValue:derefed];
                }
            }
        }

        
        
        if (item.fields.notes.length) {
            [orderedFields addKey:NSLocalizedString(@"generic_fieldname_notes", @"Notes") andValue:[self maybeDereference:item.fields.notes]];
        }
        
        

        NSMutableArray<UIView*>* fieldViews = [NSMutableArray array];

        if (item.fields.otpToken) {
            self.otpToken = item.fields.otpToken;
            [self createTotpLabel];
            [fieldViews addObject:self.totpLabel];
        }
        [fieldViews addObject:stackViewTitle];

        int fieldsStartIndex = (int) fieldViews.count;
        
        for (NSString* key in orderedFields.allKeys) {
            NSString* value = orderedFields[key];
        
            [fieldViews addObject:[self createHeaderLabel:key]];
            [fieldViews addObject:[self createFieldLabel:value]];
        }
        
        
        
        UIStackView* stackView = [[UIStackView alloc] initWithArrangedSubviews:fieldViews];
        
        stackView.spacing = 10;
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.alignment = UIStackViewAlignmentLeading;
        stackView.distribution = UIStackViewDistributionFill; 
        stackView.layoutMargins = UIEdgeInsetsMake(8, 8, 8, 8);
        stackView.layoutMarginsRelativeArrangement = YES;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        
        
        
        for (int i=0;i<orderedFields.count;i++) {
            [stackView setCustomSpacing:2 afterView:fieldViews[fieldsStartIndex + (i*2)]];
        }
        
        [self.view addSubview:stackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [imageView.widthAnchor constraintEqualToConstant:32],
            [imageView.heightAnchor constraintEqualToConstant:32],
            [stackView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [stackView.widthAnchor constraintGreaterThanOrEqualToConstant:250], 
        ]];
        
        CGSize size = [stackView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        self.preferredContentSize = size;
    }
    
    return self;
}

- (UILabel*)createFieldLabel:(NSString*)value  {
    UILabel *ret = [[UILabel alloc] init];
    
    ret.font = FontManager.sharedInstance.regularFont;
    ret.textColor = UIColor.labelColor;
    ret.text = value;
    
    [ret.widthAnchor constraintLessThanOrEqualToConstant:300].active = YES;
    
    return ret;
}

- (UILabel*)createHeaderLabel:(NSString*)heading  {
    UILabel *ret = [[UILabel alloc] init];
    
    ret.font = FontManager.sharedInstance.caption2Font;
    ret.textColor = UIColor.secondaryLabelColor;
    ret.text = heading;
    
    [ret.widthAnchor constraintLessThanOrEqualToConstant:300].active = YES;
    
    return ret;
}

- (void)createTotpLabel  {
    self.totpLabel = [[UILabel alloc] init];
    
    self.totpLabel.font = FontManager.sharedInstance.easyReadFontForTotp;
    self.totpLabel.textAlignment = NSTextAlignmentCenter;
    [self.totpLabel.widthAnchor constraintEqualToConstant:300].active = YES;
    
    [self updateTotpLabel];
}

- (void)updateTotpLabel {
    uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
    self.totpLabel.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
    self.totpLabel.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.systemBlueColor;
    self.totpLabel.alpha = 1;
    
    if(remainingSeconds < 16) {
        [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
            self.totpLabel.alpha = 0.5;
        } completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self startOtpRefresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self killOtpTimer];
}

- (void)killOtpTimer {
    if(self.timerRefreshOtp) {
        slog(@"Kill Preview OTP Timer");
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (void)startOtpRefresh {
    if (!self.otpToken) {
        return;
    }
    
    slog(@"Starting Preview OTP Timer");

    self.timerRefreshOtp =  [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self updateTotpLabel];
    }];
    
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
}

- (NSString*)maybeDereference:(NSString*)text {
    return self.model.metadata.viewDereferencedFields ? [self.model.database dereference:text node:self.item] : text;
}

@end
