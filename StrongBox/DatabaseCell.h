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
topSubtitle:(NSString*_Nullable)topSubtitle
  subtitle1:(NSString*_Nullable)subtitle1
  subtitle2:(NSString*_Nullable)subtitle2
providerIcon:(UIImage*_Nullable)providerIcon
statusImage:(UIImage*_Nullable)statusImage
   disabled:(BOOL)disabled;

@end

NS_ASSUME_NONNULL_END
