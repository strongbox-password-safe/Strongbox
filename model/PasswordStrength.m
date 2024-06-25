//
//  PasswordStrength.m
//  Strongbox
//
//  Created by Strongbox on 12/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "PasswordStrength.h"
#import "Utils.h"

@interface PasswordStrength ()

@property double timeToCrackInSeconds;
@property BOOL showCharacterCount;
@property NSUInteger characterCount;

@end

const NSUInteger kSecondsInAnHour = 60 * 60;
const NSUInteger kSecondsInADay = 24 * kSecondsInAnHour;
const NSUInteger kSecondsInAYear = kSecondsInADay * 365;
const NSUInteger kSecondsInACentury = 100 * kSecondsInAYear;
const NSUInteger kSecondsInAThousandYears = 1000 * kSecondsInAYear;
const NSUInteger kSecondsInAMillionYears = 1000000 * kSecondsInAYear;

@implementation PasswordStrength

+ (instancetype)withEntropy:(double)entropy guessesPerSecond:(NSUInteger)guessesPerSecond characterCount:(NSUInteger)characterCount showCharacterCount:(BOOL)showCharacterCount {
    return [[PasswordStrength alloc] initWithEntropy:entropy guessesPerSecond:guessesPerSecond characterCount:characterCount showCharacterCount:showCharacterCount];
}

- (instancetype)initWithEntropy:(double)entropy guessesPerSecond:(NSUInteger)guessesPerSecond characterCount:(NSUInteger)characterCount showCharacterCount:(BOOL)showCharacterCount {
    self = [super init];
    
    if (self) {
        self.entropy = entropy;
        self.timeToCrackInSeconds = calculateCrackingTime(entropy, guessesPerSecond);
        self.showCharacterCount = showCharacterCount;
        self.characterCount = characterCount;
    }
    
    return self;
}

double calculateCrackingTime(double entropy, NSUInteger guessesPerSecond) {
    double searchSpace = pow(2, entropy-1); 
    
    double secs = searchSpace / guessesPerSecond;
    
    
    
    return secs;
}

- (NSString *)summaryString {
    NSString* entropy = [NSString stringWithFormat:@"%0.1f", self.entropy];
    
    if ( self.showCharacterCount ) {
        NSString* fmt = NSLocalizedString (@"password_strength_summary_char_count_fmt", @"%@ (%@ / %@ bits / %@)");
        return [NSString stringWithFormat:fmt, self.category, @(self.characterCount), entropy, self.timeToCrack];
    }
    else {
        NSString* fmt = NSLocalizedString (@"password_strength_summary_fmt", @"%@ (%@ bits / %@)");
        return [NSString stringWithFormat:fmt, self.category, entropy, self.timeToCrack];
    }
}

- (NSString *)timeToCrack {
    double millionYears = self.timeToCrackInSeconds / kSecondsInAMillionYears;
    
    if ( millionYears > 100 ) {
        return NSLocalizedString(@"password_time_to_crack_more_than_100m_years", @">100m years");
    }
    else if (millionYears > 1 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_million_years_fmt", @"%@m years"), @(((NSUInteger)millionYears))];
    }

    NSUInteger thousandYears = self.timeToCrackInSeconds / kSecondsInAThousandYears;
    if (thousandYears > 9 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_thousand_years_fmt", @"%@k years"), @(thousandYears)];
    }

    NSUInteger centuries = self.timeToCrackInSeconds / kSecondsInACentury;
    if (centuries > 0 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_centuries_fmt", @"%@ centuries"), @(centuries)];
    }

    NSUInteger years = self.timeToCrackInSeconds / kSecondsInAYear;
    if (years > 0 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_years_fmt", @"%@ years"), @(years)];
    }
    
    NSUInteger days = self.timeToCrackInSeconds / kSecondsInADay;
    if (days > 0 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_days_fmt", @"%@ days"), @(days)];
    }
    
    NSUInteger hours = self.timeToCrackInSeconds / kSecondsInAnHour;
    if (hours > 0 ) {
        return [NSString stringWithFormat:NSLocalizedString(@"password_time_to_crack_hours_fmt", @"%@ hours"), @(hours)];
    }
    
    NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];
    
    fmt.allowedUnits =  NSCalendarUnitMinute | NSCalendarUnitSecond;
    fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
    
    return [fmt stringFromTimeInterval:self.timeToCrackInSeconds];
}

- (NSString *)category {
    
    
    
    
    














    
    if (self.entropy < 28.0f) {
        return NSLocalizedString(@"password_strength_category_very_weak", @"Very Weak");
    }
    else if (self.entropy < 36.0f) {
        return NSLocalizedString(@"password_strength_category_weak", @"Weak");
    }
    else if (self.entropy < 60.0f) {
        return NSLocalizedString(@"password_strength_category_mediocre", @"Mediocre");
    }
    else if (self.entropy < 128.0f) {
        return NSLocalizedString(@"password_strength_category_strong", @"Strong");
    }
    else if (self.entropy < 192.0f) {
        return NSLocalizedString(@"password_strength_category_very_strong", @"Very Strong");
    }
    else {
        return NSLocalizedString(@"password_strength_category_overkill", @"Overkill");
    }
}

@end
