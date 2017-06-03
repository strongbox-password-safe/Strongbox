//
//  StorageBrowserItem.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StorageBrowserItem : NSObject

@property (nonatomic) BOOL folder;
@property (nonatomic) NSString *name;
@property (nonatomic) NSObject *providerData;

@end
