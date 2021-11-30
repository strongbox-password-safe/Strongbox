//
//  StrongboxConstants.h
//  Strongbox
//
//  Created by Strongbox on 25/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StrongboxErrorCodes : NSObject

@property (readonly, class) NSInteger incorrectCredentials;
@property (readonly, class) NSInteger couldNotCreateICloudFile;
@property (readonly, class) NSInteger macOSBiometricInProgressOrImpossible;

@end

NS_ASSUME_NONNULL_END
