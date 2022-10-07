//
//  AutoFillProxy.h
//  MacBox
//
//  Created by Strongbox on 14/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#ifndef AutoFillProxy_h
#define AutoFillProxy_h

NS_ASSUME_NONNULL_BEGIN

NSString* _Nullable getSocketPath(BOOL hardcodeSandboxTestingPath);
NSString* _Nullable sendMessageOverSocket (NSString* request, BOOL hardcodeSandboxTestingPath, NSError** error);
id readJsonObjectFromInputStream (NSInputStream* inputStream, BOOL returnJsonInsteadOfObject );

NS_ASSUME_NONNULL_END

#endif /* AutoFillProxy_h */
