//
//  TotpCell.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TotpCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *labelTotp;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

NS_ASSUME_NONNULL_END
