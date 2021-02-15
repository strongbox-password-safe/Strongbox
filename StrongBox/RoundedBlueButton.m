//
//  RoundedBlueButton.m
//  Strongbox
//
//  Created by Mark on 07/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "RoundedBlueButton.h"

@implementation RoundedBlueButton

- (void)awakeFromNib {
    [super awakeFromNib];

    self.layer.cornerRadius = 5.0f;
    self.backgroundColor = UIColor.systemBlueColor;
    [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
}

@end
