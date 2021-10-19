//
//  MarkdownCell.h
//  Strongbox
//
//  Created by Strongbox on 27/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownCell : UITableViewCell

- (void)setNotes:(NSString*)notes;

@property (nonatomic, copy) void (^onNotesDoubleTap)(void);

@end

NS_ASSUME_NONNULL_END
