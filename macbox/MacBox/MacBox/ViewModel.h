//
//  ViewModel.h
//  MacBox
//
//  Created by Mark on 09/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreModel.h"

@interface ViewModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithData:(NSData*)data;

@property (nonatomic, readonly) BOOL locked;
- (void)lock;
- (BOOL)unlock:(NSString*)password error:(NSError**)error;

//@property (nonatomic) BOOL modelOutOfSyncWithData;
//- (void)syncModelToData;

@property (strong, nonatomic) NSData* data;
@property (strong, nonatomic) CoreModel* unlockedDbModel;

@end
