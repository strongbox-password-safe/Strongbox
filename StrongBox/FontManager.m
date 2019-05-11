//
//  FontManager.m
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "FontManager.h"
#import "Settings.h"

static NSString* const kEasyReadFontName = @"Menlo";

@implementation FontManager

+ (instancetype)sharedInstance {
    static FontManager *sharedInstance = nil;

    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FontManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self buildFonts];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onFontSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    return self;
}

- (void)buildFonts {
    _regularFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

    UIFontDescriptor* desc = [self.regularFont.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    _italicFont = [UIFont fontWithDescriptor:desc size:0];

    UIFont* customFont = [UIFont fontWithName:kEasyReadFontName size:UIFont.labelFontSize];
    if (@available(iOS 11.0, *)) {
        _easyReadFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:customFont];
    } else {
        _easyReadFont = customFont;
    }
    _easyReadFontForTotp = [UIFont fontWithName:kEasyReadFontName size:26.0];
    
    
    NSLog(@"Fonts built: [%@-%@-%@]", self.regularFont, self.easyReadFont, self.easyReadFontForTotp);
}

- (void)onFontSizeChanged:(NSNotificationCenter*)center {
    NSLog(@"Content Size did change notification... rebuilding fonts...");
    [self buildFonts];
}

- (UIFont *)configuredValueFont {
    BOOL useEasyReadFontInAllFields = Settings.sharedInstance.easyReadFontForAll;
    
    return useEasyReadFontInAllFields ? self.easyReadFont : self.regularFont;
}

@end
