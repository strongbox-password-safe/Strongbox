//
//  SelectedStorageParameters.m
//  Strongbox-iOS
//
//  Created by Mark on 01/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SelectedStorageParameters.h"

@implementation SelectedStorageParameters

+ (instancetype)userCancelled {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.method = kStorageMethodUserCancelled;
    ret.error = nil;
    
    return ret;
}

+ (instancetype)error:(NSError*)error withProvider:(id<SafeStorageProvider>)provider {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.method = kStorageMethodErrorOccurred;
    ret.provider = provider;
    ret.error = error;
    
    return ret;
}

+ (instancetype)parametersForFilesApp:(NSURL*)url withProvider:(id<SafeStorageProvider>)provider makeALocalCopy:(BOOL)makeALocalCopy {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.provider = provider;
    ret.method = kStorageMethodFilesAppUrl;
    ret.parentFolder = url;
    ret.url = url;
    ret.filesAppMakeALocalCopy = makeALocalCopy;
    
    return ret;
}

+ (instancetype)parametersForManualDownload:(NSData*)data {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.method = kStorageMethodManualUrlDownloadedData;
    ret.data = data;
    
    return ret;
}

+ (instancetype)parametersForNativeProviderExisting:(id<SafeStorageProvider>)provider
                                               file:(StorageBrowserItem *)file
                                       likelyFormat:(DatabaseFormat)likelyFormat
                                               data:(NSData *)data
                                initialDateModified:(NSDate *)initialDateModified {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.method = kStorageMethodNativeStorageProvider;
    ret.provider = provider;
    ret.file = file;
    ret.likelyFormat = likelyFormat;
    ret.data = data;
    ret.initialDateModified = initialDateModified;
    
    return ret;
}

+ (instancetype)parametersForNativeProviderCreate:(id<SafeStorageProvider>)provider folder:(NSObject*)folder {
    SelectedStorageParameters* ret = [[SelectedStorageParameters alloc] init];
    
    ret.method = kStorageMethodNativeStorageProvider;
    ret.provider = provider;
    ret.parentFolder = folder;

    return ret;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Method: %d, error: [%@], url: [%@], provider: [%@]",
            self.method, self.error, self.url, self.provider ? @(self.provider.storageId) : @"nil"];
}

@end
