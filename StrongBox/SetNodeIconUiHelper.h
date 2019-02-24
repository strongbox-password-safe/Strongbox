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

typedef void (^SetNodeIconUiCompletionBlock)(BOOL goNoGo, NSNumber* _Nullable userSelectedNewIconIndex, UIImage* _Nullable userSelectedNewCustomIcon);

@interface SetNodeIconUiHelper : NSObject

- (void)changeIcon:(UIViewController*)viewController
           urlHint:(NSString* _Nullable)urlHint
            format:(DatabaseFormat)format
        completion:(SetNodeIconUiCompletionBlock)completion;

- (void)tryDownloadFavIcon:(NSString*)urlHint completion:(SetNodeIconUiCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
