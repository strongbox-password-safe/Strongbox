//
//  Kdbx4Database.h
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePass4DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4Database : NSObject<AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;
+ (NSString *)fileExtension;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

NS_ASSUME_NONNULL_END
