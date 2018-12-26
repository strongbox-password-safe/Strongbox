//
//  NSDateRFC1123.h
//  Filmfest
//
//  Created by Marcus Rohrmoser on 19.08.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Category on NSDate to add rfc1123 dates. Donated from the Filmfest App for free use as in free beer.
 http://blog.mro.name/2009/08/nsdateformatter-http-header/ and
 http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1
 */
@interface NSDate (NSDateRFC1123)

/**
 Convert a RFC1123 'Full-Date' string (http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1) into NSDate.
 @param value_ something like either @"Fri, 14 Aug 2009 14:45:31 GMT" or @"Sunday, 06-Nov-94 08:49:37 GMT" or @"Sun Nov  6 08:49:37 1994"
 @return nil if not parseable.
 */
+(NSDate*)dateFromRFC1123:(NSString*)value_;

/**
 Convert NSDate into a RFC1123 'Full-Date' string (http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3.1).
 @return something like @"Fri, 14 Aug 2009 14:45:31 GMT"
 */
-(NSString*)rfc1123String;

@end