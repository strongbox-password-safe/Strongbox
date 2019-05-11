//
//  BrowseItemCell.h
//  Strongbox
//
//  Created by Mark on 10/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowseItemCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *otpLabel;

- (void)setGroup:(NSString *)title icon:(UIImage*)icon childCount:(NSString*)childCount italic:(BOOL)italic groupLocation:(NSString*)groupLocation;
- (void)setRecord:(NSString*)title username:(NSString*)username icon:(UIImage*)icon groupLocation:(NSString*)groupLocation flags:(NSString*)flags;

@end

NS_ASSUME_NONNULL_END
