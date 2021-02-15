//
//  StorageBrowserItem.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StorageBrowserItem : NSObject

+ (instancetype)itemWithName:(NSString*)name identifier:(NSString*)identifier folder:(BOOL)folder providerData:(id)providerData;

@property (nonatomic) BOOL folder;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *identifier; 
@property (nonatomic) NSObject *providerData;

@end
