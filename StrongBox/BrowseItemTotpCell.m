//
//  BrowseItemTotpCell.m
//  Strongbox-iOS
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BrowseItemTotpCell.h"
#import "OTPToken+Generation.h"
//#import "Settings.h"
#import "Model.h"

@interface BrowseItemTotpCell ()

@property (weak, nonatomic) IBOutlet UILabel *labelOtp;
@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelUsername;
@property (weak, nonatomic) IBOutlet UIImageView *icon;
@property (weak, nonatomic) IBOutlet UILabel *labelIssuerAndName;

@property OTPToken* otpToken;

@end

@implementation BrowseItemTotpCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.icon.layer.cornerRadius = 3.0;
    self.icon.clipsToBounds = YES;
}

-(void)prepareForReuse {
    [super prepareForReuse];

    self.contentView.alpha = 1.0f;
    [self stopObservingOtpUpdateTimer];
}

- (void)setItem:(NSString*)title subtitle:(NSString*)subtitle icon:(UIImage*)icon expired:(BOOL)expired otpToken:(OTPToken*)otpToken hideIcon:(BOOL)hideIcon {
    self.labelTitle.text = title;
    self.labelUsername.text = subtitle;
    
    self.icon.image = hideIcon ? nil :icon;
    self.icon.hidden = hideIcon;
    
    self.otpToken = otpToken;
    
    self.contentView.alpha = expired ? 0.35 : 1.0f;
    
    [self bindIssuer];
    [self updateOtpCode];
    [self subscribeToOtpUpdateTimerIfNecessary];
}

- (void)bindIssuer {
    self.labelIssuerAndName.text = @"";
    self.labelIssuerAndName.hidden = YES;

    NSString* issuer = self.otpToken.issuer;
    NSString* name = self.otpToken.name;
    
    if ( issuer.length && ![issuer isEqualToString:@"<Unknown>"] && ![issuer isEqualToString:@"Strongbox"] ) {
        if ( name.length && ![name isEqualToString:@"<Unknown>"] && ![name isEqualToString:@"Strongbox"] ) {
            self.labelIssuerAndName.text = [NSString stringWithFormat:@"%@: %@", issuer, name];
        } else {
            self.labelIssuerAndName.text = issuer;
        }
        self.labelIssuerAndName.hidden = NO;
    } else if ( name.length && ![name isEqualToString:@"<Unknown>"] && ![name isEqualToString:@"Strongbox"] ) {
        self.labelIssuerAndName.text = name;
        self.labelIssuerAndName.hidden = NO;
    }
}

- (void)stopObservingOtpUpdateTimer {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)subscribeToOtpUpdateTimerIfNecessary {
    if(self.otpToken) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateOtpCode) name:kCentralUpdateOtpUiNotification object:nil];
    }
    else {
        [self stopObservingOtpUpdateTimer];
    }
}

- (IBAction)updateOtpCode {
    if(self.otpToken) {
        uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
        self.labelOtp.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
        
        self.labelOtp.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.systemBlueColor;
        
        self.labelOtp.alpha = 1;
        
        if(remainingSeconds < 16) {
            [UIView animateWithDuration:0.45
                                  delay:0.0
                                options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                             animations:^{
                self.labelOtp.alpha = 0.5;
            } completion:nil];
        }
    }
    else {
        self.labelOtp.text = @"";
    }
}

@end
