//
//  IconViewCell.h
//  Strongbox
//
//  Created by Mark on 22/02/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IconViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *labelName;

@end

NS_ASSUME_NONNULL_END
