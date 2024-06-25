//
//  ContextMenuHelper.m
//  Strongbox
//
//  Created by Strongbox on 05/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "ContextMenuHelper.h"

@implementation ContextMenuHelper

+ (UIAction *)getItem:(NSString *)title handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title systemImage:nil handler:handler];
}

+ (UIAction *)getItem:(NSString *)title checked:(BOOL)checked handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title systemImage:nil enabled:YES checked:checked handler:handler];
}

+ (UIAction *)getItem:(NSString *)title checked:(BOOL)checked systemImage:(NSString*)systemImage handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title systemImage:systemImage enabled:YES checked:checked handler:handler];
}

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler   {
    return [ContextMenuHelper getItem:title systemImage:systemImage enabled:YES handler:handler];
}

+ (UIAction *)getItem:(NSString *)title systemImage:(NSString *)systemImage colour:(UIColor *)colour handler:(UIActionHandler)handler {
    return [self getItem:title systemImage:systemImage colour:colour large:NO handler:handler];
}

+ (UIAction *)getItem:(NSString *)title systemImage:(NSString *)systemImage colour:(UIColor *)colour large:(BOOL)large handler:(UIActionHandler)handler {
    return [self getItem:title systemImage:systemImage colour:colour large:large destructive:NO enabled:YES checked:NO handler:handler];
}


+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*)systemImage enabled:(BOOL)enabled handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title systemImage:systemImage enabled:enabled checked:NO handler:handler];
}

+ (UIAction *)getItem:(NSString *)title systemImage:(NSString *)systemImage enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler {
    return [ContextMenuHelper getItem:title systemImage:systemImage colour:nil destructive:NO enabled:enabled checked:checked handler:handler];
}

+ (UIAction*)getDestructiveItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title systemImage:systemImage colour:nil destructive:YES enabled:YES checked:NO handler:handler];
}

+ (UIAction*)getItem:(NSString*)title
         systemImage:(NSString*)systemImage
              colour:(UIColor*_Nullable)colour
         destructive:(BOOL)destructive
             enabled:(BOOL)enabled
             checked:(BOOL)checked
             handler:(UIActionHandler)handler
{
    return [self getItem:title
             systemImage:systemImage
                  colour:colour
                   large:NO
             destructive:destructive
                 enabled:enabled
                 checked:checked
                 handler:handler];
}

+ (UIAction*)getItem:(NSString*)title
         systemImage:(NSString*)systemImage
              colour:(UIColor*_Nullable)colour
               large:(BOOL)large
         destructive:(BOOL)destructive
             enabled:(BOOL)enabled
             checked:(BOOL)checked
             handler:(UIActionHandler)handler {
    UIImage* image = nil;
    if ( systemImage ) {
        image = [UIImage systemImageNamed:systemImage];
        
        if ( colour ) {
            UIImageSymbolConfiguration* colourConfig = [UIImageSymbolConfiguration configurationWithHierarchicalColor:colour];
            
            if ( large ) {
                colourConfig = [colourConfig configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithScale:UIImageSymbolScaleLarge]];
            }
            
            image = [image imageByApplyingSymbolConfiguration:colourConfig];
        }
    }
    
    return [ContextMenuHelper getItem:title
                                image:image
                          destructive:destructive
                              enabled:enabled
                              checked:checked
                              handler:handler];
}

+ (UIAction *)getItem:(NSString *)title image:(UIImage *)image handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:title image:image destructive:NO enabled:YES checked:NO handler:handler];
}

+ (UIAction*)getItem:(NSString*)title image:(UIImage*)image destructive:(BOOL)destructive enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler
   {
    UIAction *ret = [UIAction actionWithTitle:title
                                        image:image
                                   identifier:nil
                                      handler:handler];
    
    if (destructive) {
        ret.attributes = UIMenuElementAttributesDestructive;
    }
        
    if (!enabled) {
        ret.attributes = UIMenuElementAttributesDisabled;
    }
    
    if (checked) {
        ret.state = UIMenuElementStateOn;
    }
    
    return ret;
}

@end
