#import "PHFComposeBarView_UtilityButton.h"

@implementation PHFComposeBarView_UtilityButton

- (void)setHighlighted:(BOOL)highlighted {
    CGFloat alpha = highlighted ? 0.2f : 1.0f;
    [self setAlpha:alpha];
}

@end
