//
//  AutoFillCredentialCell.h
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillCredentialCell : NSTableCellView

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldSubtitle;
@property (weak) IBOutlet NSTextField *textFieldTopRight;
@property (weak) IBOutlet NSTextField *textFieldBottomRight;
@property (weak) IBOutlet NSImageView *image;

@end

NS_ASSUME_NONNULL_END
