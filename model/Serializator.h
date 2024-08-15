//
//  Serializator.h
//  Strongbox
//
//  Created by Strongbox on 20/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "DatabaseModelConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^DeserializeCompletionBlock)(BOOL userCancelled, DatabaseModel *_Nullable model, NSTimeInterval decryptTime, NSError*_Nullable error);

@interface Serializator : NSObject

+ (BOOL)isValidDatabase:(NSURL*)url error:(NSError**)error;
+ (BOOL)isValidDatabaseWithPrefix:(nullable NSData *)prefix error:(NSError**)error; 

+ (NSString*_Nonnull)getLikelyFileExtension:(NSData *_Nonnull)prefix;

+ (DatabaseFormat)getDatabaseFormat:(NSURL*)url;
+ (DatabaseFormat)getDatabaseFormatWithPrefix:(NSData *)prefix;

+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format;



+ (DatabaseModel*_Nullable)expressFromData:(NSData*)data password:(NSString*)password;

+ (DatabaseModel*_Nullable)expressFromData:(NSData*)data password:(NSString*)password config:(DatabaseModelConfig*)config xml:(NSString*_Nullable*_Nullable)xml;

+ (NSString *_Nullable)expressToXml:(NSData*)data password:(NSString*)password;

+ (void)fromLegacyData:legacyData
                   ckf:(CompositeKeyFactors *)ckf
                config:(DatabaseModelConfig*)config
            completion:(DeserializeCompletionBlock)completion;

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
     completion:(DeserializeCompletionBlock)completion;

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig*)config
     completion:(DeserializeCompletionBlock)completion;

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig*)config
  xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
     completion:(DeserializeCompletionBlock)completion;

+ (void)fromUrlOrLegacyData:(NSURL *)url
                 legacyData:(NSData *)legacyData
                        ckf:(CompositeKeyFactors *)ckf
                     config:(DatabaseModelConfig*)config
                 completion:(DeserializeCompletionBlock)completion;



+ (NSData*_Nullable)expressToData:(DatabaseModel*)database format:(DatabaseFormat)format;

+ (void)getAsData:(DatabaseModel*)database format:(DatabaseFormat)format outputStream:(NSOutputStream*)outputStream completion:(SaveCompletionBlock)completion;

+ (void)getAsData:(DatabaseModel *)database
           format:(DatabaseFormat)format
     outputStream:(NSOutputStream*)outputStream
           params:(id _Nullable)params
       completion:(SaveCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
