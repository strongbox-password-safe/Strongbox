//
//  BrowseActionsHelper.h
//  Strongbox
//
//  Created by Strongbox on 29/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface BrowseActionsHelper : NSObject

- (instancetype)initWithModel:(Model*)model
               viewController:(UIViewController*)viewController
         updateDatabaseAction:(void (^)(BOOL, void(^ _Nullable)(BOOL)))updateDatabaseAction;

- (void)copyPassword:(NSUUID*)uuid;
- (void)copyAllFields:(NSUUID*)uuid;
- (void)copyUsername:(NSUUID*)uuid;
- (void)copyTotp:(NSUUID*)uuid;
- (void)copyUrl:(NSUUID*)uuid;
- (void)copyEmail:(NSUUID*)uuid;
- (void)copyNotes:(NSUUID*)uuid;
- (void)copyAndLaunch:(NSUUID*)uuid;
- (void)copyCustomField:(NSString*)key uuid:(NSUUID*)uuid;

- (void)showPassword:(NSUUID*)uuid;

#ifndef IS_APP_EXTENSION
- (void)showAuditDrillDown:(NSUUID*)uuid;
- (void)showHardwareKeySettings;
#endif

- (void)deleteSingleItem:(NSUUID * _Nonnull)uuid
              completion:(void (^)(BOOL actionPerformed))completion;

- (void)emptyRecycleBin:(void (^)(BOOL actionPerformed))completion;

- (void)onDatabaseBulkIconUpdate:(NSDictionary<NSUUID *,NodeIcon *> * _Nullable)selectedFavIcons;

- (void)presentSetCredentials;

- (void)printDatabase;
- (void)exportDatabase;

@end

NS_ASSUME_NONNULL_END
