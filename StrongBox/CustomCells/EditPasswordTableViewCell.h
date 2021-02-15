//
//  EditPasswordTableViewCell.h
//  test-new-ui
//
//  Created by Mark on 22/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditPasswordTableViewCell : UITableViewCell

@property NSString* password;

@property (nonatomic, copy) void (^onPasswordEdited)(NSString* password);
@property (nonatomic, copy) void (^onPasswordSettings)(void);
@property BOOL showGenerationSettings;
@property BOOL colorize;
@property UIViewController* parentVc;

@end

NS_ASSUME_NONNULL_END
