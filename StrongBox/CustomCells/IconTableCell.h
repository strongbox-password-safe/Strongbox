//
//  IconTableCell.h
//  Strongbox-iOS
//
//  Created by Mark on 25/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IconTableCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onIconTapped)(void);
@property (nonatomic, copy, nullable) void (^onConfigureDefaultsTapped)(void);

- (void)setModel:(NSString*)value
            icon:(UIImage*)icon
         editing:(BOOL)editing
        newEntry:(BOOL)newEntry
 selectAllOnEdit:(BOOL)selectAllOnEdit
 useEasyReadFont:(BOOL)useEasyReadFont;


@property (nonatomic, copy, nullable) void (^onTitleEdited)(NSString* text);

@end

NS_ASSUME_NONNULL_END
