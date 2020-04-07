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
@property (weak, nonatomic) IBOutlet UILabel *childCountLabel;
@property (weak, nonatomic) IBOutlet UIImageView *imageFlag1;
@property (weak, nonatomic) IBOutlet UIImageView *imageFlag2;

@property OTPToken* otpToken;


@end

@implementation BrowseItemCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

-(void)prepareForReuse {
    [super prepareForReuse];

    self.contentView.alpha = 1.0f;
    
    self.iconImageView.hidden = YES;
    self.iconImageView.image = nil;
        
    [self setFlags:NO hasAttachments:NO];
    
    [self stopObservingOtpUpdateTimer];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
          pinned:(BOOL)pinned
        hideIcon:(BOOL)hideIcon {
    return [self setGroup:title icon:icon childCount:childCount italic:italic groupLocation:groupLocation tintColor:nil pinned:pinned hideIcon:hideIcon];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage *)icon
      childCount:(NSString *)childCount
          italic:(BOOL)italic
   groupLocation:(NSString *)groupLocation
       tintColor:(UIColor*)tintColor
          pinned:(BOOL)pinned
        hideIcon:(BOOL)hideIcon {
    self.titleLabel.text = title;
    self.titleLabel.font = italic ? FontManager.sharedInstance.italicFont : FontManager.sharedInstance.regularFont;
    
    self.iconImageView.image = hideIcon ? nil : icon;
    self.iconImageView.tintColor = tintColor;
    self.iconImageView.hidden = hideIcon;
    
    self.usernameLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    [self setFlags:pinned hasAttachments:NO];

    self.otpLabel.text = @"";
    self.otpLabel.hidden = YES;
    
    self.childCountLabel.hidden = childCount.length == 0;
    self.childCountLabel.text = childCount;
    
    self.pathLabel.text = groupLocation;
    self.bottomRow.hidden = groupLocation.length == 0;
}

- (void)setRecord:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(UIImage *)icon
    groupLocation:(NSString *)groupLocation
           pinned:(BOOL)pinned
   hasAttachments:(BOOL)hasAttachments
          expired:(BOOL)expired
         otpToken:(OTPToken*)otpToken
         hideIcon:(BOOL)hideIcon {
    self.titleLabel.text = title;
    self.titleLabel.font = FontManager.sharedInstance.regularFont;
    
    self.iconImageView.image = hideIcon ? nil :icon;
    self.iconImageView.tintColor = nil;
    self.iconImageView.hidden = hideIcon;
    
    self.usernameLabel.text = subtitle;
    self.pathLabel.text = groupLocation;
    self.accessoryType = UITableViewCellAccessoryNone;
    
    [self setFlags:pinned hasAttachments:hasAttachments];

    self.childCountLabel.hidden = YES;
    self.bottomRow.hidden = subtitle.length == 0 && groupLocation.length == 0;

    self.otpLabel.hidden = NO;
    self.otpToken = otpToken;
    
    self.contentView.alpha = expired ? 0.35 : 1.0f;
    
    [self updateOtpCode];
    [self subscribeToOtpUpdateTimerIfNecessary];
}

- (void)setFlags:(BOOL)pinned hasAttachments:(BOOL)hasAttachments {
    if(pinned) {
        if (@available(iOS 13.0, *)) {
            self.imageFlag1.image = [UIImage systemImageNamed:@"pin"];
        }
        else {
            self.imageFlag1.image = pinned ? [UIImage imageNamed:@"pin"] : nil;
        }
        
        self.imageFlag1.hidden = !pinned;
        self.imageFlag2.image = hasAttachments ? [UIImage imageNamed:@"attach"] : nil;
        self.imageFlag2.hidden = !hasAttachments;
    }
    else {
        self.imageFlag1.image = hasAttachments ? [UIImage imageNamed:@"attach"] : nil;
        self.imageFlag1.hidden = !hasAttachments;
        self.imageFlag2.image = nil;
        self.imageFlag2.hidden = YES;
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
//    NSLog(@"Updating OTP Codes from Notification");
    if(self.otpToken) {
        uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
        self.otpLabel.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
        
        self.otpLabel.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.systemBlueColor;
    
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
