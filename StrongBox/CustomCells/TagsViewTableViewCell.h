//
//  TagsViewTableViewCell.h
//  Strongbox
//
//  Created by Mark on 27/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TagsViewTableViewCell : UITableViewCell

- (void)setModel:(BOOL)readOnly
            tags:(NSArray<NSString*>*)tags
 useEasyReadFont:(BOOL)useEasyReadFont;

@end

NS_ASSUME_NONNULL_END
