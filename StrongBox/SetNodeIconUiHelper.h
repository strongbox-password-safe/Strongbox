//
//  SetNodeIconUiHelper.h
//  Strongbox-iOS
//
//  Created by Mark on 23/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FavIconBulkViewController.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^ChangeIconCompletionBlock)(BOOL goNoGo, BOOL isRecursiveGroupFavIconResult, NSDictionary<NSUUID*, NodeIcon*>* _Nullable selected);

@interface SetNodeIconUiHelper : NSObject

- (void)changeIcon:(UIViewController *)viewController
              node:(Node* _Nonnull)node
       urlOverride:(NSString* _Nullable)urlOverride
            format:(DatabaseFormat)format
    keePassIconSet:(KeePassIconSet)keePassIconSet
        completion:(ChangeIconCompletionBlock)completion;

- (void)expressDownloadBestFavIcon:(NSString*)urlOverride
                        completion:(void (^)(UIImage * _Nullable))completion;

@property NSSet<NodeIcon*>* customIconPool;

@end

NS_ASSUME_NONNULL_END
