//
//  QRCodePresenterPopover.m
//  Strongbox
//
//  Created by Mark on 10/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "QRCodePresenterPopover.h"

@interface QRCodePresenterPopover ()

@property (weak) IBOutlet NSImageView *imageView;

@end

@implementation QRCodePresenterPopover

- (void)viewWillAppear {
    [super viewWillAppear];

    self.imageView.image = self.qrCodeImage;
}

@end
