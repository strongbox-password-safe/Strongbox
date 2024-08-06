//
//  TotpCell.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "TotpCell.h"
#import "FontManager.h"
#import "OTPToken+Generation.h"
#import "Model.h"

@interface TotpCell ()

@property (weak, nonatomic) IBOutlet UILabel *labelTotp;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *buttonShowQrCode;
@property (weak, nonatomic) IBOutlet UILabel *labelIssuerAndName;

@property OTPToken* otpToken;

@end

@implementation TotpCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

-(void)prepareForReuse {
    [super prepareForReuse];
    [self stopObservingOtpUpdateTimer];
}

- (void)stopObservingOtpUpdateTimer {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)subscribeToOtpUpdateTimerIfNecessary {
    if(self.otpToken) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(updateOtpToken) name:kCentralUpdateOtpUiNotification object:nil];
    }
    else {
        [self stopObservingOtpUpdateTimer];
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.labelTotp.font = FontManager.sharedInstance.easyReadFontForTotp;
}

- (void)setItem:(OTPToken*)otpToken {
    self.otpToken = otpToken;
    
    [self bindIssuer];
    [self updateOtpToken];
    [self subscribeToOtpUpdateTimerIfNecessary];
}

- (void)updateOtpToken {
    if(self.otpToken) {
        uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
        self.labelTotp.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
        
        UIColor *color = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.systemBlueColor;
                
        self.labelTotp.textColor = color;
        self.labelTotp.alpha = 1;
        
        if(remainingSeconds < 16) {
            [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
                self.labelTotp.alpha = 0.5;
            } completion:nil];
        }
        
        CGFloat blah = remainingSeconds / self.otpToken.period;

        
        [UIView animateWithDuration:1.3 delay:0.0 options:UIViewAnimationOptionRepeat animations:^{
            [self.progressView setProgress:blah animated:YES];
        } completion:nil];
        
        self.progressView.tintColor = color;
    }
    else {
        self.labelTotp.text = NSLocalizedString(@"totp_cell_no_totp_has_been_setup", @"No TOTP Setup");
        self.labelTotp.textColor = nil;
    }
}

- (IBAction)onShowQRCode:(id)sender {
    if ( self.onShowQrCode ) {
        self.onShowQrCode();
    }
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

@end
