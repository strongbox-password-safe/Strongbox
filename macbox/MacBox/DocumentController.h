//
//  DocumentController.h
//  MacBox
//
//  Created by Mark on 21/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface DocumentController : NSDocumentController

- (void)originalOpenDocument:(id _Nullable)sender;
- (void)openDatabase:(DatabaseMetadata*)database completion:(void (^_Nullable)(NSError* error))completion;

- (BOOL)databaseIsDocumentWindow:(DatabaseMetadata*)database;
- (BOOL)databaseIsUnlockedInDocumentWindow:(DatabaseMetadata*)database;
- (void)closeDocumentWindowForDatabase:(DatabaseMetadata *)database;

- (void)onAppStartup;
- (void)performEmptyLaunchTasksIfNecessary;

@end

NS_ASSUME_NONNULL_END
