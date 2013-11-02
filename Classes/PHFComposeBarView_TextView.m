#import "PHFComposeBarView_TextView.h"

@implementation PHFComposeBarView_TextView

// Only allow iOS to set the offset when the user scrolls or is selecting
// text. Else it sets it in unpredictable ways which we don't want.
- (void)setContentOffset:(CGPoint)contentOffset {
    if ([self selectedRange].length || [self isTracking] || [self isDecelerating])
        [super setContentOffset:contentOffset];
}

// Expose the original -setContentOffset: method.
- (void)PHFComposeBarView_setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
}

@end
