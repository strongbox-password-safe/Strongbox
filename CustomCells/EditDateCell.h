//
//  EditDateCell.h
//  Strongbox
//
//  Created by Mark on 28/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditDateCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *keyLabel;

- (void)setDate:(NSDate*)date;

@property (nonatomic, copy, nullable) void (^onDateChanged)(NSDate*_Nullable date);

@end

NS_ASSUME_NONNULL_END
