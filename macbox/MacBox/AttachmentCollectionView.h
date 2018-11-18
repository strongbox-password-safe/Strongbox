//
//  AttachmentCollectionView.h
//  Strongbox
//
//  Created by Mark on 16/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface AttachmentCollectionView : NSCollectionView

@property (copy)void (^onDoubleClick)(void);
@property (copy)void (^onSpaceBar)(void);

@end

NS_ASSUME_NONNULL_END
