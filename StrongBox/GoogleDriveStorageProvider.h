//
//  GoogleDriveStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "GoogleDriveManager.h"

@interface GoogleDriveStorageProvider : NSObject <SafeStorageProvider>
@property GoogleDriveManager *googleDrive;
@end
