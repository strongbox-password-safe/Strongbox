//
//  EditAttachmentCell.h
//  test-new-ui
//
//  Created by Mark on 23/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EditAttachmentCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIView *horizontalLine;

@end

NS_ASSUME_NONNULL_END
