//
//  AddNewSafeHelper.m
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "AddNewSafeHelper.h"
#import "Alerts.h"
#import "SafesList.h"

@implementation AddNewSafeHelper

+ (void)addNewSafeAndPopToRoot:(UIViewController*)vc name:(NSString *)name password:(NSString *)password provider:(id<SafeStorageProvider>)provider format:(DatabaseFormat)format {
    DatabaseModel *newSafe = [[DatabaseModel alloc] initNewWithPassword:password keyFileDigest:nil format:format];
    
    NSError *error;
    NSData *data = [newSafe getAsData:&error];
    
    if (data == nil) {
        [Alerts error:vc title:@"Error Saving Database" error:error];
        return;
    }
    
    [provider create:name
           extension:newSafe.fileExtension
                data:data
        parentFolder:nil
      viewController:vc
          completion:^(SafeMetaData *metadata, NSError *error)
     {
         if (error == nil) {
             if(metadata.storageProvider == kiCloud) {
                 NSUInteger existing = [SafesList.sharedInstance.snapshot indexOfObjectPassingTest:^BOOL(SafeMetaData * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                     return obj.storageProvider == kiCloud && [obj.fileName isEqualToString:metadata.fileName];
                 }];
                 
                 if(existing == NSNotFound) { // May have already been added by our iCloud watch thread.
                     NSLog(@"Adding as this iCloud filename is not already present.");
                     [[SafesList sharedInstance] add:metadata];
                 }
                 else {
                     NSLog(@"Not Adding as this iCloud filename is already present. Probably picked up by Watch Thread.");
                 }
             }
             else {
                 [[SafesList sharedInstance] add:metadata];
             }
         }
         else {
             NSLog(@"An error occurred: %@", error);
             
             [Alerts error:vc
                     title:@"Error Saving Database"
                     error:error];
         }
         
         [vc.navigationController popToRootViewControllerAnimated:YES];
     }];
}

@end
