//
//  TotpCell.m
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "TotpCell.h"
#import "FontManager.h"

@implementation TotpCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.labelTotp.font = FontManager.sharedInstance.easyReadFontForTotp;
}

@end
