//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "ODCollectionRequest.h"
#import "ODCollection.h"
#import "ODClient.h"

@implementation ODCollectionRequest

- (ODURLSessionDataTask *)collectionTaskWithRequest:(NSMutableURLRequest *)request
                             odObjectWithDictionary:(ODObject* (^)(NSDictionary *response))castBlock
                                         completion:(void (^)(ODCollection *response, NSError *error))completionHandler
{
    return [self taskWithRequest:request
          odObjectWithDictionary: ^ODCollection *(NSDictionary *rawResponse){
                           NSMutableArray *odObjects = [NSMutableArray array];
                           __block ODCollection *parsedCollection = nil;
                           if (rawResponse[@"value"]){
                               [rawResponse[@"value"] enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                                   id value = castBlock(obj);
                                   if (value){
                                       [odObjects addObject:value];
                                   }
                                   else{
                                       // There was a failure in parsing the item
                                       [self.client.logger logWithLevel:ODLogError message:@"Failed to parse collection"];
                                       [self.client.logger logWithLevel:ODLogDebug message:@"Object failed  to parse : %@", obj];
                                       *stop = YES;
                                   }
                               }];
                               // if we were able to parse all of the items in the collection
                               if ([odObjects count] == [rawResponse[@"value"] count]){
                                   parsedCollection = [[ODCollection alloc] initWithArray:odObjects
                                                                                 nextLink:rawResponse[@"@odata.nextLink"]
                                                                           additionalData:rawResponse];
                               }
                               else{
                                   [self.client.logger logWithLevel:ODLogDebug message:@"Failed to parse collection objects expected %ld there were %ld", [rawResponse[@"value"] count], [odObjects count]];
                               }
                               
                           }
                           else{
                               [self.client.logger logWithLevel:ODLogError message:@"Collection contains no value property"];
                               [self.client.logger logWithLevel:ODLogDebug message:@"Response was : %@", rawResponse];
                           }
                            return parsedCollection;
                       }
                       completion:completionHandler];
}
@end
