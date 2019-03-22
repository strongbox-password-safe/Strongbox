//
//  SetNodeIconUiHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 23/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ChangeIconCompletionBlock)(BOOL goNoGo, NSNumber* _Nullable userSelectedNewIconIndex, NSUUID*_Nullable userSelectedExistingCustomIconId, UIImage* _Nullable userSelectedNewCustomIcon);
typedef void (^DownloadFavIconCompletionBlock)(BOOL goNoGo, UIImage* _Nullable userSelectedNewCustomIcon);

@interface SetNodeIconUiHelper : NSObject

- (void)changeIcon:(UIViewController*)viewController
           urlHint:(NSString* _Nullable)urlHint
            format:(DatabaseFormat)format
        completion:(ChangeIconCompletionBlock)completion;

- (void)tryDownloadFavIcon:(NSString*)urlHint completion:(DownloadFavIconCompletionBlock)completion;

@property NSDictionary<NSUUID*, NSData*>* customIcons;

@end

NS_ASSUME_NONNULL_END
