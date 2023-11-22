//
//  BrowseItemCell.h
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTPToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemCell : UITableViewCell

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
           flags:(NSArray<UIImage*>*)flags
  flagTintColors:(NSDictionary<NSNumber*, UIColor*> *_Nullable)flagTintColors
        hideIcon:(BOOL)hideIcon;

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
       tintColor:(UIColor* _Nullable )tintColor
           flags:(NSArray<UIImage*>*)flags
  flagTintColors:(NSDictionary<NSNumber*, UIColor*> *_Nullable)flagTintColors
        hideIcon:(BOOL)hideIcon;

- (void)setGroup:(NSString *)title
            icon:(UIImage*)icon
      childCount:(NSString*)childCount
          italic:(BOOL)italic
   groupLocation:(NSString*)groupLocation
       tintColor:(UIColor* _Nullable )tintColor
           flags:(NSArray<UIImage*>*)flags
  flagTintColors:(NSDictionary<NSNumber*, UIColor*> *_Nullable)flagTintColors
        hideIcon:(BOOL)hideIcon
       textColor:(UIColor* _Nullable)textColor;


- (void)setRecord:(NSString*)title
         subtitle:(NSString*)subtitle
             icon:(UIImage*)icon
    groupLocation:(NSString*)groupLocation
            flags:(NSArray<UIImage*>*)flags
   flagTintColors:(NSDictionary<NSNumber*, UIColor*> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken*_Nullable)otpToken
         hideIcon:(BOOL)hideIcon;

- (void)setRecord:(NSString*)title
         subtitle:(NSString*)subtitle
             icon:(UIImage*)icon
    groupLocation:(NSString*)groupLocation
            flags:(NSArray<UIImage*>*)flags
   flagTintColors:(NSDictionary<NSNumber*, UIColor*> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken*_Nullable)otpToken
         hideIcon:(BOOL)hideIcon
            audit:(NSString*_Nullable)audit;

- (void)setRecord:(NSString*)title
         subtitle:(NSString*)subtitle
             icon:(UIImage*)icon
    groupLocation:(NSString*)groupLocation
            flags:(NSArray<UIImage*>*)flags
   flagTintColors:(NSDictionary<NSNumber*, UIColor*> *)flagTintColors
          expired:(BOOL)expired
         otpToken:(OTPToken*_Nullable)otpToken
         hideIcon:(BOOL)hideIcon
            audit:(NSString*_Nullable)audit
   imageTintColor:(UIColor* _Nullable )imageTintColor;

@end

NS_ASSUME_NONNULL_END
