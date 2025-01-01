//
//  BrowseItemCell.m
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BrowseItemCell.h"
#import "FontManager.h"
#import "OTPToken+Generation.h"
#import "Constants.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface BrowseItemCell ()

@property (weak, nonatomic) IBOutlet UIView *bottomRow;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;
@property (weak, nonatomic) IBOutlet UILabel *childCount;
@property (weak, nonatomic) IBOutlet UIImageView *imageFlag1;
@property (weak, nonatomic) IBOutlet UIImageView *imageFlag2;
@property (weak, nonatomic) IBOutlet UIImageView *imageFlag3;
@property (weak, nonatomic) IBOutlet UILabel *labelAudit;
@property (weak, nonatomic) IBOutlet UIImageView *iconImageView;

@property (weak, nonatomic) IBOutlet UILabel *otpLabel1;
@property (weak, nonatomic) IBOutlet UIImageView *otpSeparator;
@property (weak, nonatomic) IBOutlet UILabel *otpLabel2;
@property (weak, nonatomic) IBOutlet UIStackView *otpStack;

@property OTPToken* otpToken;

@end

@implementation BrowseItemCell

- (void)dealloc {
    [self stopObservingOtpUpdateTimer];
}

- (void)awakeFromNib {
    [super awakeFromNib];
 
    self.iconImageView.layer.cornerRadius = 3.0;
    self.iconImageView.clipsToBounds = YES;
}

-(void)prepareForReuse {
    [super prepareForReuse];

    self.contentView.alpha = 1.0f;
    
    self.iconImageView.hidden = YES;
    self.iconImageView.image = nil;
    
    [self setFlags:@[] flagTintColors:nil];
    
    [self stopObservingOtpUpdateTimer];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
           flags:(NSArray<UIImage*>*)flags
  flagTintColors:(NSDictionary<NSNumber *,UIColor *> * _Nullable)flagTintColors
        hideIcon:(BOOL)hideIcon {
    return [self setGroup:title
                     icon:icon
               childCount:childCount
                   italic:italic
            groupLocation:groupLocation
                tintColor:nil
                    flags:flags
           flagTintColors:flagTintColors
                 hideIcon:hideIcon];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage *)icon
      childCount:(NSString *)childCount
          italic:(BOOL)italic
   groupLocation:(NSString *)groupLocation
       tintColor:(UIColor*)tintColor
           flags:(NSArray<UIImage *> *)flags
  flagTintColors:(NSDictionary<NSNumber *,UIColor *> * _Nullable)flagTintColors
        hideIcon:(BOOL)hideIcon {
    return [self setGroup:title
                     icon:icon
               childCount:childCount
                   italic:italic
            groupLocation:groupLocation
                tintColor:nil
                    flags:flags
           flagTintColors:flagTintColors
                 hideIcon:hideIcon
                textColor:nil];
}

- (void)setGroup:(NSString *)title
            icon:(UIImage *)icon
      childCount:(NSString *)childCount
          italic:(BOOL)italic
   groupLocation:(NSString *)groupLocation
       tintColor:(UIColor *)tintColor
           flags:(NSArray<UIImage *> *)flags
  flagTintColors:(NSDictionary<NSNumber *,UIColor *> *)flagTintColors
        hideIcon:(BOOL)hideIcon
       textColor:(UIColor *)textColor {
    self.titleLabel.text = title;
    self.titleLabel.font = italic ? FontManager.sharedInstance.italicFont : FontManager.sharedInstance.regularFont;
    self.titleLabel.textColor = textColor ? textColor : UIColor.labelColor;
    
    self.iconImageView.image = hideIcon ? nil : icon;
    self.iconImageView.tintColor = tintColor;
    self.iconImageView.hidden = hideIcon;
        
    self.usernameLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    [self setFlags:flags flagTintColors:flagTintColors];

    self.otpLabel1.text = @"";
    self.otpLabel2.text = @"";
    self.otpLabel1.hidden = YES;
    self.otpLabel2.hidden = YES;
    self.otpSeparator.hidden = YES;
    
    self.childCount.hidden = childCount.length == 0;
    self.childCount.text = childCount;
    
    self.labelAudit.hidden = YES;
    
    self.pathLabel.text = groupLocation;
    self.bottomRow.hidden = groupLocation.length == 0;
}

- (void)setRecord:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(UIImage *)icon
    groupLocation:(NSString *)groupLocation
            flags:(NSArray<UIImage *> *)flags
   flagTintColors:(nonnull NSDictionary<NSNumber *,UIColor *> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken *)otpToken
         hideIcon:(BOOL)hideIcon {
    [self setRecord:title
           subtitle:subtitle
               icon:icon
      groupLocation:groupLocation
              flags:flags
     flagTintColors:flagTintColors
            expired:expired
           otpToken:otpToken
           hideIcon:hideIcon
              audit:nil];
}

- (void)setRecord:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(UIImage *)icon
    groupLocation:(NSString *)groupLocation
            flags:(NSArray<UIImage *> *)flags
   flagTintColors:(nonnull NSDictionary<NSNumber *,UIColor *> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken *)otpToken
         hideIcon:(BOOL)hideIcon
            audit:(NSString*_Nullable)audit {
    [self setRecord:title
           subtitle:subtitle
               icon:icon
      groupLocation:groupLocation
              flags:flags
     flagTintColors:flagTintColors
            expired:expired
           otpToken:otpToken
           hideIcon:hideIcon
              audit:nil
     imageTintColor:nil];
}

- (void)setRecord:(NSString *)title
         subtitle:(NSString *)subtitle
             icon:(UIImage *)icon
    groupLocation:(NSString *)groupLocation
            flags:(NSArray<UIImage *> *)flags
   flagTintColors:(NSDictionary<NSNumber *,UIColor *> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken *)otpToken
         hideIcon:(BOOL)hideIcon
            audit:(NSString *)audit
   imageTintColor:(UIColor *)imageTintColor {
    self.titleLabel.text = title.length ? title : @" ";
    self.titleLabel.font = FontManager.sharedInstance.headlineFont;
    self.titleLabel.textColor = UIColor.labelColor;
    
    self.iconImageView.image = hideIcon ? nil :icon;
    self.iconImageView.tintColor = imageTintColor;
    self.iconImageView.hidden = hideIcon;
    
    self.usernameLabel.text = subtitle;
    self.pathLabel.text = groupLocation;
    self.accessoryType = UITableViewCellAccessoryNone;
    
    [self setFlags:flags flagTintColors:flagTintColors];

    self.childCount.hidden = YES;
    self.labelAudit.hidden = audit == nil;
    
    if (audit) {
        self.labelAudit.text = audit;
    }
    
    self.bottomRow.hidden = subtitle.length == 0 && groupLocation.length == 0;

    self.otpLabel1.font = FontManager.sharedInstance.easyReadBoldFont;
    self.otpLabel2.font = FontManager.sharedInstance.easyReadBoldFont;
    
    self.otpToken = otpToken;
    
    self.contentView.alpha = expired ? 0.35 : 1.0f;
    
    [self updateOtpCode];
    [self subscribeToOtpUpdateTimerIfNecessary];
}

- (void)setFlags:(NSArray<UIImage*>*)flags flagTintColors:(NSDictionary<NSNumber *,UIColor *> *)flagTintColors {
    UIImage* flag1 = flags.count > 0 ? flags[0] : nil;
    UIImage* flag2 = flags.count > 1 ? flags[1] : nil;
    UIImage* flag3 = flags.count > 2 ? flags[2] : nil;
    
    self.imageFlag1.hidden = flag1 == nil;
    self.imageFlag2.hidden = flag2 == nil;
    self.imageFlag3.hidden = flag3 == nil;
    
    self.imageFlag1.image = flag1;
    self.imageFlag2.image = flag2;
    self.imageFlag3.image = flag3;
    
    [self.imageFlag1 setTintColor:nil];
    [self.imageFlag2 setTintColor:nil];
    [self.imageFlag3 setTintColor:nil];

    if (flagTintColors) {
        if (flagTintColors[@(0)]) {
            [self.imageFlag1 setTintColor:flagTintColors[@(0)]];
        }
        if (flagTintColors[@(1)]) {
            [self.imageFlag2 setTintColor:flagTintColors[@(1)]];
        }
        if (flagTintColors[@(2)]) {
            [self.imageFlag3 setTintColor:flagTintColors[@(2)]];
        }
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
        NSArray<NSString*>* codes = self.otpToken.codeSeparated;
        if ( codes && codes.count == 2 && AppPreferences.sharedInstance.twoFactorEasyReadSeparator ) {
            [self updateOtpNewStyle:codes];
        }
        else {
            [self updateOtpLegacyStyle];
        }
    }
    else {
        self.otpLabel1.hidden = YES;
        self.otpLabel2.hidden = YES;
        self.otpSeparator.hidden = YES;

    }
}

- (void)updateOtpNewStyle:(NSArray<NSString*>*)codes {
    self.otpLabel1.text = codes[0];
    self.otpLabel2.text = codes[1];

    uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
    self.otpLabel1.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.labelColor;
    self.otpLabel2.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.labelColor;
    
    self.otpLabel2.alpha = 1;
    self.otpLabel1.alpha = 1;

    self.otpLabel1.hidden = NO;
    self.otpLabel2.hidden = NO;
    self.otpSeparator.hidden = NO;
}

- (void)updateOtpLegacyStyle {
    uint64_t remainingSeconds = self.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)self.otpToken.period);
    
    self.otpLabel1.text = [NSString stringWithFormat:@"%@", self.otpToken.password];
    self.otpLabel1.textColor = (remainingSeconds < 5) ? UIColor.systemRedColor : (remainingSeconds < 9) ? UIColor.systemOrangeColor : UIColor.systemBlueColor;
    self.otpLabel1.alpha = 1;






    
    self.otpLabel1.hidden = NO;
    self.otpLabel2.hidden = YES;
    self.otpSeparator.hidden = YES;
}

@end
