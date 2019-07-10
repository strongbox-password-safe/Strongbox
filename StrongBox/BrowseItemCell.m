//
//  BrowseItemCell.m
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "BrowseItemCell.h"
#import "FontManager.h"
#import "OTPToken+Generation.h"
#import "Settings.h"

@interface BrowseItemCell ()

@property (weak, nonatomic) IBOutlet UIView *bottomRow;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;
@property (weak, nonatomic) IBOutlet UILabel *flagsLabel;
@property (weak, nonatomic) IBOutlet UILabel *childCountLabel;

@property OTPToken* otpToken;

@end

@implementation BrowseItemCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

-(void)prepareForReuse {
    [super prepareForReuse];
    [self stopObservingOtpUpdateTimer];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation {
    return [self setGroup:title icon:icon childCount:childCount italic:italic groupLocation:groupLocation tintColor:nil];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage *)icon
      childCount:(NSString *)childCount
          italic:(BOOL)italic
   groupLocation:(NSString *)groupLocation
       tintColor:(UIColor*)tintColor {
    self.titleLabel.text = title;
    self.titleLabel.font = italic ? FontManager.sharedInstance.italicFont : FontManager.sharedInstance.regularFont;
    
    self.iconImageView.image = icon;
    self.iconImageView.tintColor = tintColor;
    
    self.usernameLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    self.flagsLabel.text = @"";
    self.otpLabel.text = @"";
    self.otpLabel.hidden = YES;
    self.flagsLabel.hidden = YES;

    self.childCountLabel.hidden = childCount.length == 0;
    self.childCountLabel.text = childCount;
    
    self.pathLabel.text = groupLocation;
    self.bottomRow.hidden = groupLocation.length == 0;
}

- (void)setRecord:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(UIImage *)icon
    groupLocation:(NSString *)groupLocation
            flags:(NSString*)flags
         otpToken:(OTPToken*)otpToken {
    self.titleLabel.text = title;
    self.titleLabel.font = FontManager.sharedInstance.regularFont;
    self.iconImageView.image = icon;
    self.iconImageView.tintColor = nil;

    self.usernameLabel.text = subtitle;
    self.pathLabel.text = groupLocation;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.flagsLabel.text = flags;
    self.flagsLabel.hidden = NO;
    self.childCountLabel.hidden = YES;
    self.bottomRow.hidden = subtitle.length == 0 && groupLocation.length == 0;

    self.otpLabel.hidden = NO;
    self.otpToken = otpToken;
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
//    NSLog(@"Updating OTP Codes from Notification");
    if(self.otpToken) {
        uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
        self.otpLabel.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
        self.otpLabel.textColor = (remainingSeconds < 5) ? [UIColor redColor] : (remainingSeconds < 9) ? [UIColor orangeColor] : [UIColor blueColor];
        self.otpLabel.alpha = 1;
        
        if(remainingSeconds < 16) {
            [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
                self.otpLabel.alpha = 0.5;
            } completion:nil];
        }
    }
    else {
        self.otpLabel.text = @"";
    }
}

@end
