//
//  BrowseItemCell.h
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTPToken.h"
//#import "SWTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *otpLabel;

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
          pinned:(BOOL)pinned
        hideIcon:(BOOL)hideIcon;

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
       tintColor:(UIColor* _Nullable )tintColor
          pinned:(BOOL)pinned
        hideIcon:(BOOL)hideIcon;

- (void)setRecord:(NSString*)title
         subtitle:(NSString*)subtitle
             icon:(UIImage*)icon
    groupLocation:(NSString*)groupLocation
           pinned:(BOOL)pinned
   hasAttachments:(BOOL)hasAttachments
          expired:(BOOL)expired
         otpToken:(OTPToken*_Nullable)otpToken
         hideIcon:(BOOL)hideIcon;

@end

NS_ASSUME_NONNULL_END
