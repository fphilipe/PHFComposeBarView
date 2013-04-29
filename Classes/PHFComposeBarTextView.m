#import "PHFComposeBarTextView.h"

@implementation PHFComposeBarTextView

// Only allow iOS to set the offset when the user scrolls or is selecting
// text. Else it sets it in unpredictable ways which we don't want.
- (void)setContentOffset:(CGPoint)contentOffset {
    if (([self selectedRange].length) || [self isTracking] || [self isDecelerating])
        [super setContentOffset:contentOffset];
}

// Work around to manually set the offset.
- (void)PHFSetContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
}

// Slightly decrease the carret size as in iMessage. Only works in iOS 5.
- (CGRect)caretRectForPosition:(UITextPosition *)position {
    CGRect rect = [super caretRectForPosition:position];
    rect.size.height -= 2;
    rect.origin.y    += 1;

    return rect;
}

// iOS 4 constantly resets the bottom inset to some value. We want to keep it at
// -10 in order to prevent scrolling.
- (void)setContentInset:(UIEdgeInsets)contentInset {
    contentInset.bottom = -10;
    [super setContentInset:contentInset];
}

@end
