#import <Foundation/Foundation.h>

@interface NSString (Levenshtein)

- (NSUInteger)levenshteinDistance:(NSString *)string;
- (double)levenshteinSimilarityRatio:(NSString*)string;

@end
