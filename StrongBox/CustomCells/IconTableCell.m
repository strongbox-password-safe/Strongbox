//
//  IconTableCell.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "IconTableCell.h"

@implementation IconTableCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapped)];
    singleTap.numberOfTapsRequired = 1;
    [self.iconImage addGestureRecognizer:singleTap];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onIconTapped = nil;
}

- (void)onTapped {
    if(self.onIconTapped) {
        self.onIconTapped();
    }
}

@end
