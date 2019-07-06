//
//  NSCheckboxTableCellView.h
//  Strongbox
//
//  Created by Mark on 03/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSCheckboxTableCellView : NSTableCellView

@property (weak) IBOutlet NSButton *checkbox;

@property (nonatomic, copy) void (^onClicked)(BOOL);

@end

NS_ASSUME_NONNULL_END
