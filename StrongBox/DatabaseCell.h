//
//  DatabaseCell.h
//  Strongbox
//
//  Created by Mark on 30/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kDatabaseCell;

@interface DatabaseCell : UITableViewCell

- (void)set:(NSString*)name
topSubtitle:(NSString*)topSubtitle
  subtitle1:(NSString*)subtitle1
  subtitle2:(NSString*)subtitle2
providerIcon:(UIImage*_Nullable)providerIcon
statusImages:(NSArray<UIImage*>*)statusImages
rotateLastImage:(BOOL)rotateLastImage
lastImageTint:(UIColor*_Nullable)lastImageTint
   disabled:(BOOL)disabled;

@end

NS_ASSUME_NONNULL_END
