//
//  Document.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "CompositeKeyFactors.h"
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document : NSDocument

- (instancetype)initWithCredentials:(DatabaseFormat)format compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors;

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
            selectedItem:(NSString * _Nullable)selectedItem
              completion:(void (^)(BOOL, NSError * _Nullable))completion;

- (void)setDatabaseMetadata:(DatabaseMetadata*)databaseMetadata; 

@end

NS_ASSUME_NONNULL_END

