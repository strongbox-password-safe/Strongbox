//
//  XmlOutputStreamWriter.h
//  Strongbox
//
//  Created by Strongbox on 14/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "XMLWriter.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlOutputStreamWriter : XMLWriter

- (instancetype)initWithOutputStream:(NSOutputStream*)outputStream;

@end

NS_ASSUME_NONNULL_END
