//
//  DatabaseCell.m
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "DatabaseCell.h"

NSString* const kDatabaseCell = @"DatabaseCell";

@interface DatabaseCell ()

@property (weak, nonatomic) IBOutlet UIImageView *providerIcon;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *subtitle1;
@property (weak, nonatomic) IBOutlet UILabel *subtitle2;
@property (weak, nonatomic) IBOutlet UILabel *topSubtitle;
@property (weak, nonatomic) IBOutlet UIView *bottomRow;

@property (weak, nonatomic) IBOutlet UIImageView *status1;
@property (weak, nonatomic) IBOutlet UIImageView *status2;
@property (weak, nonatomic) IBOutlet UIImageView *status3;
@property (weak, nonatomic) IBOutlet UIImageView *status4;

@end

@implementation DatabaseCell

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.bottomRow.hidden = NO;
    self.subtitle1.hidden = NO;
    self.subtitle2.hidden = NO;
    self.topSubtitle.hidden = NO;
    
    self.status1.image = nil;
    self.status1.hidden = YES;
    self.status2.image = nil;
    self.status2.hidden = YES;
    self.status3.image = nil;
    self.status3.hidden = YES;
    self.status4.image = nil;
    self.status4.hidden = YES;
}

- (void)setEnabled:(BOOL)enabled {
    self.imageView.userInteractionEnabled = enabled;
    self.userInteractionEnabled = enabled;
    self.textLabel.enabled = enabled;
    self.detailTextLabel.enabled = enabled;
    self.name.enabled = enabled;
    self.subtitle1.enabled = enabled;
    self.subtitle2.enabled = enabled;
    self.providerIcon.userInteractionEnabled = enabled;
    self.topSubtitle.enabled = enabled;
    
    self.status1.userInteractionEnabled = enabled;
    self.status2.userInteractionEnabled = enabled;
    self.status3.userInteractionEnabled = enabled;
    self.status4.userInteractionEnabled = enabled;
}

- (void)set:(NSString*)name
topSubtitle:(NSString*)topSubtitle
  subtitle1:(NSString*)subtitle1
  subtitle2:(NSString*)subtitle2
providerIcon:(UIImage*)providerIcon
statusImages:(NSArray<UIImage*>*)statusImages
rotateLastImage:(BOOL)rotateLastImage
lastImageTint:(UIColor *)lastImageTint
   disabled:(BOOL)disabled {
    self.name.text = name;

    self.providerIcon.image = providerIcon;
    self.providerIcon.hidden = providerIcon == nil;

    self.topSubtitle.text = topSubtitle ? topSubtitle : @"";
    self.subtitle1.text = subtitle1 ? subtitle1 : @"";
    self.subtitle2.text = subtitle2 ? subtitle2 : @"";
    
    self.subtitle1.hidden = subtitle1 == nil;
    self.subtitle2.hidden = subtitle2 == nil;
    self.topSubtitle.hidden = topSubtitle == nil;
    
    self.bottomRow.hidden = subtitle1 == nil && subtitle2 == nil;

    NSArray<UIImageView*>* statusImageControls = @[self.status1, self.status2, self.status3, self.status4];
    
    for (int i = 0; i < statusImageControls.count; i++) {
        UIImage* image = i < statusImages.count ? statusImages[i] : nil;
        statusImageControls[i].image = image;
        statusImageControls[i].hidden = image == nil;
        
        if (i == statusImages.count - 1) {
            if (rotateLastImage) {
                [self runSpinAnimationOnView:statusImageControls[i] duration:1.0 rotations:1.0 repeat:1024 * 1024];
            }
            
            statusImageControls[i].tintColor = lastImageTint;
        }
    }
    
    [self setEnabled:!disabled];
}

- (void) runSpinAnimationOnView:(UIView*)view duration:(CGFloat)duration rotations:(CGFloat)rotations repeat:(float)repeat {
    [view.layer removeAllAnimations];
    
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 /* full rotation*/ * rotations * duration ];
    rotationAnimation.duration = duration;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = repeat ? HUGE_VALF : 0;

    [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}

@end
