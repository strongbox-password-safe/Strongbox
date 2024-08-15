//
//  Serializator.m
//  Strongbox
//
//  Created by Strongbox on 20/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Serializator.h"
#import "StreamUtils.h"
#import "LoggingInputStream.h"
#import "Constants.h"
#import "Utils.h"
#import "KeePassDatabase.h"
#import "PwSafeDatabase.h"
#import "Kdbx4Database.h"
#import "Kdb1Database.h"
#import "NSData+Extensions.h"
#import "StreamUtils.h"

@implementation Serializator

+ (NSData*_Nullable)getValidationPrefixFromUrl:(NSURL*)url {
    NSInputStream* inputStream = [NSInputStream inputStreamWithURL:url];
    
    [inputStream open];
    
    uint8_t buf[kMinimumDatabasePrefixLengthForValidation];
    NSInteger bytesRead = [inputStream read:buf maxLength:kMinimumDatabasePrefixLengthForValidation];
    
    [inputStream close];
    
    if (bytesRead > 0) {
        return [NSData dataWithBytes:buf length:bytesRead];
    }
    
    return nil;
}

+ (BOOL)isValidDatabase:(NSURL *)url error:(NSError *__autoreleasing  _Nullable *)error {
    NSData* prefix = [Serializator getValidationPrefixFromUrl:url];
    
    return [Serializator isValidDatabaseWithPrefix:prefix error:error];
}

+ (BOOL)isValidDatabaseWithPrefix:(NSData *)prefix error:(NSError *__autoreleasing  _Nullable *)error {
    if(prefix == nil) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is Nil" errorCode:-1];
        }
        return NO;
    }
    if(prefix.length == 0) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is zero length" errorCode:-1];
        }
        return NO;
    }
    
    NSError *pw, *k1, *k2, *k3;
    
    BOOL ret = [PwSafeDatabase isValidDatabase:prefix error:&pw] ||
    [KeePassDatabase isValidDatabase:prefix error:&k1] ||
    [Kdbx4Database isValidDatabase:prefix error:&k2] ||
    [Kdb1Database isValidDatabase:prefix error:&k3];
    
    if(!ret && error) {
        NSData* prefixBytes = [prefix subdataWithRange:NSMakeRange(0, MIN(24, prefix.length))];
        
        NSString* errorSummary = @"Invalid Database. Debug Info:\n";
        
        NSString* prefix = prefixBytes.upperHexString;
        NSString* utf8Prefix = [[NSString alloc] initWithData:prefixBytes encoding:NSUTF8StringEncoding];
        
        if([prefix hasPrefix:@"004D534D414D415250435259"]) { 
            NSString* loc = NSLocalizedString(@"error_database_is_encrypted_ms_intune", @"It looks like your database is encrypted by Microsoft InTune probably due to corporate policy.");
            
            errorSummary = loc;
        }
        else {
            errorSummary = [errorSummary stringByAppendingFormat:@"PFX: Hex: [%@] UTF8: [%@]\n", prefix, utf8Prefix ? utf8Prefix : @"-"];
            errorSummary = [errorSummary stringByAppendingFormat:@"PWS: [%@]\n", pw.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP:[%@]-[%@]\n", k1.localizedDescription, k2.localizedDescription];
            errorSummary = [errorSummary stringByAppendingFormat:@"KP1: [%@]\n", k3.localizedDescription];
        }
        
        *error = [Utils createNSError:errorSummary errorCode:-1];
    }
    
    return ret;
}

+ (DatabaseFormat)getDatabaseFormat:(NSURL *)url {
    NSData* prefix = [Serializator getValidationPrefixFromUrl:url];
    return [Serializator getDatabaseFormatWithPrefix:prefix];
}

+ (DatabaseFormat)getDatabaseFormatWithPrefix:(NSData *)prefix {
    if(prefix == nil || prefix.length == 0) {
        return kFormatUnknown;
    }
    
    NSError* error;
    if([PwSafeDatabase isValidDatabase:prefix error:&error]) {
        return kPasswordSafe;
    }
    else if ([KeePassDatabase isValidDatabase:prefix error:&error]) {
        return kKeePass;
    }
    else if([Kdbx4Database isValidDatabase:prefix error:&error]) {
        return kKeePass4;
    }
    else if([Kdb1Database isValidDatabase:prefix error:&error]) {
        return kKeePass1;
    }
    
    return kFormatUnknown;
}

+ (NSString*)getLikelyFileExtension:(NSData *)prefix {
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:prefix];
    
    if (format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if (format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    else {
        return @"dat";
    }
}

+ (NSString*)getDefaultFileExtensionForFormat:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [PwSafeDatabase fileExtension];
    }
    else if (format == kKeePass) {
        return [KeePassDatabase fileExtension];
    }
    else if(format == kKeePass4) {
        return [Kdbx4Database fileExtension];
    }
    else if(format == kKeePass1) {
        return [Kdb1Database fileExtension];
    }
    
    return [Kdbx4Database fileExtension];
}

+ (id)getAdaptor:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [PwSafeDatabase class];
    }
    else if(format == kKeePass) {
        return [KeePassDatabase class];
    }
    else if(format == kKeePass4) {
        return [Kdbx4Database class];
    }
    else if(format == kKeePass1) {
        return [Kdb1Database class];
    }
    
    slog(@"WARN: No such adaptor for format!");
    return nil;
}



+ (NSData *)expressToData:(DatabaseModel *)database format:(DatabaseFormat)format {
    __block NSData* ret;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    NSOutputStream* memStream = [NSOutputStream outputStreamToMemory];
    [memStream open];
    
    [Serializator getAsData:database
                     format:format
               outputStream:memStream
                 completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
        [memStream close];
        
        if (userCancelled || error) {
            slog(@"Error: expressToData [%@]", error);
        }
        else {
            ret = [memStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        }
        dispatch_group_leave(group);
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return ret;
}

+ (void)getAsData:(DatabaseModel *)database
           format:(DatabaseFormat)format
     outputStream:(NSOutputStream*)outputStream
       completion:(SaveCompletionBlock)completion {
    [Serializator getAsData:database format:format outputStream:outputStream params:nil completion:completion];
}

+ (void)getAsData:(DatabaseModel *)database
           format:(DatabaseFormat)format
     outputStream:(NSOutputStream*)outputStream
           params:(id _Nullable)params
       completion:(SaveCompletionBlock)completion {
    [database preSerializationPerformMaintenanceOrMigrations]; 

    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];

    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
        
    [adaptor save:database
     outputStream:outputStream
           params:params 
       completion:^(BOOL userCancelled, NSString*_Nullable debugXml, NSError*_Nullable error){

        slog(@"🐞 Serializator::SERIALIZE [%f] seconds", NSDate.timeIntervalSinceReferenceDate - startTime);

        
        completion(userCancelled, nil, error);
    }];
}

+ (DatabaseModel *)expressFromData:(NSData *)data password:(NSString *)password {
    return [self expressFromData:data password:password config:DatabaseModelConfig.defaults xml:nil];
}

+ (NSString *)expressToXml:(NSData*)data password:(NSString*)password {
    NSString* xml = nil;
    
    [self expressFromData:data password:password config:DatabaseModelConfig.defaults xml:&xml];

    return xml;
}

+ (DatabaseModel *)expressFromData:(NSData *)data password:(NSString *)password config:(DatabaseModelConfig *)config xml:(NSString**)xml {
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:data];
    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];
    if (adaptor == nil) {
       return nil;
    }

    NSOutputStream* xmlDumpStream = [NSOutputStream outputStreamToMemory];
    [xmlDumpStream open];

    __block DatabaseModel* model = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSInputStream* stream = [NSInputStream inputStreamWithData:data];
    [stream open];
    [adaptor read:stream
              ckf:[CompositeKeyFactors password:password]
    xmlDumpStream:xmlDumpStream
sanityCheckInnerStream:config.sanityCheckInnerStream
       completion:^(BOOL userCancelled, DatabaseModel * _Nullable database, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        [stream close];
      
        if( userCancelled || database == nil || error || innerStreamError ) {
            slog(@"Error: expressFromData = [%@]", error);
            model = nil;
        }
        else {
            model = database;
        }
        
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    if ( model ) {
        NSData *contents = [xmlDumpStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        
        if ( contents ) {
            if ( xml ) {
                *xml = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
            }
        }
    }
    
    [xmlDumpStream close];
    
    return model;
}



+ (void)fromUrlOrLegacyData:(NSURL *)url
                 legacyData:(NSData *)legacyData
                        ckf:(CompositeKeyFactors *)ckf
                     config:(DatabaseModelConfig *)config
                 completion:(nonnull DeserializeCompletionBlock)completion {
    if (url) {
        [Serializator fromUrl:url ckf:ckf config:config completion:completion];
    }
    else {
        [Serializator fromLegacyData:legacyData ckf:ckf config:config completion:completion];
    }
}

+ (void)fromLegacyData:legacyData
                   ckf:(CompositeKeyFactors *)ckf
                config:(DatabaseModelConfig*)config
            completion:(nonnull DeserializeCompletionBlock)completion {
    NSInputStream* stream = [NSInputStream inputStreamWithData:legacyData];
    
    DatabaseFormat format = [Serializator getDatabaseFormatWithPrefix:legacyData];

    [Serializator fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:nil
                             completion:completion];
}

+ (void)fromUrl:(NSURL *)url ckf:(CompositeKeyFactors *)ckf completion:(DeserializeCompletionBlock)completion {
    [Serializator fromUrl:url ckf:ckf config:DatabaseModelConfig.defaults completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
     completion:(nonnull DeserializeCompletionBlock)completion {
    [Serializator fromUrl:url ckf:ckf config:config xmlDumpStream:nil  completion:completion];
}

+ (void)fromUrl:(NSURL *)url
            ckf:(CompositeKeyFactors *)ckf
         config:(DatabaseModelConfig *)config
  xmlDumpStream:(NSOutputStream *)xmlDumpStream
     completion:(nonnull DeserializeCompletionBlock)completion {
    DatabaseFormat format = [Serializator getDatabaseFormat:url];
     
    NSInputStream* stream = [NSInputStream inputStreamWithURL:url];
    
    
    
    
    [Serializator fromStreamWithFormat:stream
                                    ckf:ckf
                                 config:config
                                 format:format
                          xmlDumpStream:xmlDumpStream
                             completion:completion];
}

+ (void)fromStreamWithFormat:(NSInputStream *)stream
                         ckf:(CompositeKeyFactors *)ckf
                      config:(DatabaseModelConfig*)config
                      format:(DatabaseFormat)format
               xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
                  completion:(nonnull DeserializeCompletionBlock)completion {
    id<AbstractDatabaseFormatAdaptor> adaptor = [Serializator getAdaptor:format];

    if (adaptor == nil) {
        completion(NO, nil, 0, nil);
        return;
    }
    
    NSTimeInterval startDecryptTime = NSDate.timeIntervalSinceReferenceDate;
    
    [stream open];
        
    [adaptor read:stream
              ckf:ckf
    xmlDumpStream:xmlDumpStream
     sanityCheckInnerStream:config.sanityCheckInnerStream
       completion:^(BOOL userCancelled, DatabaseModel * _Nullable database, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        [stream close];
        
        NSTimeInterval decryptTime = NSDate.timeIntervalSinceReferenceDate - startDecryptTime;
        

        slog(@"🐞 Serializator::DESERIALIZE [%f] seconds", decryptTime);


        if(userCancelled || database == nil || error || innerStreamError ) {
            completion(userCancelled, nil, decryptTime, error ? error : innerStreamError);
        }
        else {
            completion(NO, database, decryptTime, nil);
        }
    }];
}


@end
