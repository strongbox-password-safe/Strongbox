//
//  ConnectionCellView.h
//  MacBox
//
//  Created by Strongbox on 06/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionCellView : NSTableCellView

@property (weak) IBOutlet NSTextField *textFieldName;
@property (weak) IBOutlet NSTextField *textFieldHost;
@property (weak) IBOutlet NSTextField *textFieldUsedBy;
@property (weak) IBOutlet NSTextField *textFieldUser;

@end

NS_ASSUME_NONNULL_END
