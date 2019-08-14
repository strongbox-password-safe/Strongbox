//
//  BrowseItemTotpCell.m
//  Strongbox-iOS
//
//  Created by Mark on 17/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BrowseItemTotpCell.h"
#import "OTPToken+Generation.h"
#import "Settings.h"

@interface BrowseItemTotpCell ()

@property (weak, nonatomic) IBOutlet UILabel *labelOtp;
@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelUsername;
@property (weak, nonatomic) IBOutlet UIImageView *icon;

@property OTPToken* otpToken;

@end

@implementation BrowseItemTotpCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

-(void)prepareForReuse {
    [super prepareForReuse];

    self.contentView.alpha = 1.0f;
    [self stopObservingOtpUpdateTimer];
}

- (void)setItem:(NSString*)title subtitle:(NSString*)subtitle icon:(UIImage*)icon expired:(BOOL)expired otpToken:(OTPToken*)otpToken {
    self.labelTitle.text = title;
    self.labelUsername.text = subtitle;
    self.icon.image = icon;
    
    self.otpToken = otpToken;
    
    self.contentView.alpha = expired ? 0.35 : 1.0f;
    
    [self updateOtpCode];
    [self subscribeToOtpUpdateTimerIfNecessary];
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
        self.labelOtp.textColor = (remainingSeconds < 5) ? [UIColor redColor] : (remainingSeconds < 9) ? [UIColor orangeColor] : [UIColor blueColor];
        self.labelOtp.alpha = 1;
        
        if(remainingSeconds < 16) {
            [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
                self.labelOtp.alpha = 0.5;
            } completion:nil];
        }
    }
    else {
        self.labelOtp.text = @"";
    }
}

@end
