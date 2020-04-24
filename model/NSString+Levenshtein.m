#import "NSString+Levenshtein.h"

@implementation NSString (Levenshtein)

- (double)levenshteinSimilarityRatio:(NSString *)string {
    NSUInteger distance = [self levenshteinDistance:string];
    
    double distanceRatio = (((double)distance) / (MAX(self.length, string.length)));
    
    return 1.0 - distanceRatio;
}

- (NSUInteger)levenshteinDistance:(NSString*)stringB {
    NSString* stringA = self;
    
    NSUInteger n = [stringA length];
    NSUInteger m = [stringB length];
    
    if (n == 0) {
        return m;
    }
    if (m == 0) {
        return n;
    }
    
    n++;
    m++;
    NSInteger *d = malloc(sizeof(NSInteger) * m * n);
    
    for(NSInteger k = 0; k < n; k++) {
        d[k] = k;
    }
    for(NSInteger k = 0; k < m; k++) {
        d[k * n] = k;
    }
    
    for(NSInteger i = 1; i < n; i++ ) {
        for(NSInteger j = 1; j < m; j++ ) {
            NSInteger change = ([stringA characterAtIndex: i-1] == [stringB characterAtIndex: j-1]) ? 0 : 1;
            d[ j * n + i ] = MIN(d [ (j - 1) * n + i ] + 1, MIN(d[ j * n + i - 1 ] +  1, d[ (j - 1) * n + i -1 ] + change));
        }
    }
    
    NSInteger distance = d[n * m - 1];
    free( d );
    return distance;
}

@end
