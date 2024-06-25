//
//  ContextMenuHelper.h
//  Strongbox
//
//  Created by Strongbox on 05/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContextMenuHelper : NSObject

+ (UIAction*)getItem:(NSString*)title handler:(UIActionHandler)handler ;

+ (UIAction *)getItem:(NSString *)title checked:(BOOL)checked handler:(UIActionHandler)handler ;

+ (UIAction *)getItem:(NSString *)title checked:(BOOL)checked systemImage:(NSString*)systemImage handler:(UIActionHandler)handler;

+ (UIAction*)getItem:(NSString*)title image:(UIImage*_Nullable)image handler:(UIActionHandler)handler ;

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage handler:(UIActionHandler)handler ;

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage colour:(UIColor*)colour handler:(UIActionHandler)handler;

+ (UIAction *)getItem:(NSString *)title systemImage:(NSString *)systemImage colour:(UIColor *)colour large:(BOOL)large handler:(UIActionHandler)handler;

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage enabled:(BOOL)enabled handler:(UIActionHandler)handler ;

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler ;

+ (UIAction*)getDestructiveItem:(NSString*)title systemImage:(NSString*_Nullable)systemImage handler:(UIActionHandler)handler ;






+ (UIAction*)getItem:(NSString*)title
         systemImage:(NSString*)systemImage
              colour:(UIColor*_Nullable)colour
               large:(BOOL)large
         destructive:(BOOL)destructive
             enabled:(BOOL)enabled
             checked:(BOOL)checked
             handler:(UIActionHandler)handler;

@end

NS_ASSUME_NONNULL_END
