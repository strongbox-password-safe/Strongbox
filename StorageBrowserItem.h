//
//  StorageBrowserItem.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StorageBrowserItem : NSObject

+ (instancetype)itemWithName:(NSString*)name identifier:(NSString*_Nullable)identifier folder:(BOOL)folder providerData:(id _Nullable)providerData;
+ (instancetype)itemWithName:(NSString*)name identifier:(NSString*_Nullable)identifier folder:(BOOL)folder canNotCreateDatabaseInThisFolder:(BOOL)canCreateDatabaseInThisFolder providerData:(id _Nullable)providerData;

@property (nonatomic) BOOL folder;
@property (nonatomic) BOOL canNotCreateDatabaseInThisFolder;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *identifier; 
@property (nonatomic, nullable) NSObject *providerData;
@property BOOL disabled;

@end

NS_ASSUME_NONNULL_END
