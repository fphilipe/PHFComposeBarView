#import <QuartzCore/QuartzCore.h>
#import <PHFDelegateChain/PHFDelegateChain.h>
#import "PHFComposeBarView.h"
#import "PHFComposeBarTextView.h"


CGFloat const PHFComposeBarViewInitialHeight = 40.0f;


NSString *const PHFComposeBarViewDidChangeFrameNotification  = @"PHFComposeBarViewDidChangeFrame";
NSString *const PHFComposeBarViewWillChangeFrameNotification = @"PHFComposeBarViewWillChangeFrame";

NSString *const PHFComposeBarViewFrameBeginUserInfoKey        = @"PHFComposeBarViewFrameBegin";
NSString *const PHFComposeBarViewFrameEndUserInfoKey          = @"PHFComposeBarViewFrameEnd";
NSString *const PHFComposeBarViewAnimationDurationUserInfoKey = @"PHFComposeBarViewAnimationDuration";
NSString *const PHFComposeBarViewAnimationCurveUserInfoKey    = @"PHFComposeBarViewAnimationCurve";


CGFloat const kHorizontalPadding         =  6.0f;
CGFloat const kTopPadding                =  8.0f;
CGFloat const kBottomPadding             =  5.0f;
CGFloat const kTextViewSidePadding       =  2.0f;
CGFloat const kTextViewTopPadding        = -6.0f;
CGFloat const kTextViewScrollInsetTop    =  6.0f;
CGFloat const kTextViewScrollInsetBottom =  2.0f;
CGFloat const kPlaceholderHeight         = 25.0f;
CGFloat const kPlaceholderSidePadding    = 12.0f;
CGFloat const kPlaceholderTopPadding     =  0.0f;
CGFloat const kButtonWidth               = 58.0f;
CGFloat const kButtonHeight              = 27.0f;
CGFloat const kUtilityButtonWidth        = 26.0f;
CGFloat const kUtilityButtonHeight       = 27.0f;
CGFloat const kCaretYOffset              =  9.0f;


UIViewAnimationOptions const kResizeAnimationCurve = UIViewAnimationOptionCurveEaseInOut;
UIViewAnimationOptions const kScrollAnimationCurve = UIViewAnimationOptionCurveEaseInOut;
NSTimeInterval const kResizeAnimationDuration    = 0.1;
NSTimeInterval const kScrollAnimationDuration    = 0.1;
NSTimeInterval const kResizeAnimationDelay       = 0.0;
NSTimeInterval const kScrollAnimationDelay       = 0.1;


// Calculated at runtime:
static CGFloat kTextViewLineHeight;
static CGFloat kTextViewFirstLineHeight;
static CGFloat kTextViewToSuperviewHeightDelta;


@interface PHFComposeBarView ()
@property (strong, nonatomic, readonly) UIImageView *backgroundView;
@property (strong, nonatomic, readonly) UIButton *button;
@property (strong, nonatomic, readonly) UILabel *charCountLabel;
@property (strong, nonatomic) PHFDelegateChain *delegateChain;
@property (strong, nonatomic, readonly) UIButton *textContainer;
@property (strong, nonatomic, readonly) UIImageView *textFieldImageView;
@property (strong, nonatomic, readonly) UIButton *utilityButton;
@property (assign, nonatomic) CGFloat previousTextHeight;
@end


@implementation PHFComposeBarView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    [self calculateRuntimeConstants];
    [self setup];

    return self;
}

- (void)setup {
    _autoAdjustTopOffset = YES;
    _enabled = YES;
    _maxHeight = 200.0f;

    [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin];

    [self addSubview:[self backgroundView]];
    [self addSubview:[self charCountLabel]];
    [self addSubview:[self button]];
    [self addSubview:[self textContainer]];
}

- (void)calculateRuntimeConstants {
    kTextViewLineHeight             = [[[self textView] font] lineHeight];
    kTextViewFirstLineHeight        = kTextViewLineHeight + [[[self textView] font] pointSize];
    kTextViewToSuperviewHeightDelta = PHFComposeBarViewInitialHeight - kTextViewFirstLineHeight;
}

- (void)setAutoAdjustTopOffset:(BOOL)autoAdjustTopOffset {
    if (_autoAdjustTopOffset != autoAdjustTopOffset) {
        _autoAdjustTopOffset = autoAdjustTopOffset;

        UIViewAutoresizing autoresizingMask = [self autoresizingMask];

        if (autoAdjustTopOffset)
            autoresizingMask |= UIViewAutoresizingFlexibleTopMargin;
        else
            autoresizingMask ^= UIViewAutoresizingFlexibleTopMargin;

        [self setAutoresizingMask:autoresizingMask];
    }
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)resignFirstResponder {
    return [[self textView] resignFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return [[self textView] canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder {
    return [[self textView] becomeFirstResponder];
}

- (void)didMoveToSuperview {
    // Disabling the button before insertion into view will cause it to look
    // disabled but it will in fact still be tappable. To work around this
    // issue, update the enabled state once inserted into view.
    [self updateButtonEnabled];
    [self resizeTextViewIfNeededAnimated:NO];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self resizeTextViewIfNeededAnimated:YES];
}

- (void)setupDelegateChainForTextView {
    PHFDelegateChain *delegateChain = [PHFDelegateChain delegateChainWithObjects:self, [self delegate], nil];
    [self setDelegateChain:delegateChain];
    [[self textView] setDelegate:(id<UITextViewDelegate>)delegateChain];
}

#pragma mark - Public Methods

- (CGFloat)maxLinesCount {
    CGFloat maxTextHeight = [self maxHeight] - PHFComposeBarViewInitialHeight + kTextViewLineHeight;
    return maxTextHeight / kTextViewLineHeight;
}
- (void)setMaxLinesCount:(CGFloat)maxLinesCount {
    CGFloat maxTextHeight = maxLinesCount * kTextViewLineHeight;
    CGFloat maxHeight     = maxTextHeight - kTextViewLineHeight + PHFComposeBarViewInitialHeight;
    [self setMaxHeight:maxHeight];
}

@synthesize maxHeight = _maxHeight;
- (void)setMaxHeight:(CGFloat)maxHeight {
    _maxHeight = maxHeight;
    [self resizeTextViewIfNeededAnimated:YES];
    [self scrollToCaretIfNeeded];
}

@synthesize maxCharCount = _maxCharCount;
- (void)setMaxCharCount:(NSUInteger)count {
    if (_maxCharCount != count) {
        _maxCharCount = count;
        [[self charCountLabel] setHidden:(_maxCharCount == 0)];
        [self updateCharCountLabel];
    }
}

- (NSString *)placeholder {
    return [[self placeholderLabel] text];
}

- (void)setPlaceholder:(NSString *)placeholder {
    [[self placeholderLabel] setText:placeholder];
}

- (NSString *)text {
    return [[self textView] text];
}

- (void)setText:(NSString *)text {
    [[self textView] setText:text];
    [self textViewDidChange:[self textView]];
}

@synthesize buttonTitle = _buttonTitle;
- (NSString *)buttonTitle {
    if (!_buttonTitle)
        _buttonTitle = NSLocalizedStringWithDefaultValue(@"Button Title",
                                                        nil,
                                                        [NSBundle bundleForClass:[self class]],
                                                        @"Send",
                                                        @"The default value for the main button");

    return _buttonTitle;
}

- (void)setButtonTitle:(NSString *)buttonTitle {
    if (_buttonTitle != buttonTitle) {
        _buttonTitle = buttonTitle;
        [[self button] setTitle:buttonTitle forState:UIControlStateNormal];
    }
}

@synthesize delegate = _delegate;
- (void)setDelegate:(id<PHFComposeBarViewDelegate>)delegate {
    if (_delegate != delegate) {
        _delegate = delegate;
        [self setupDelegateChainForTextView];
    }
}

- (void)updateUtilityButtonVisibility {
    if ([self utilityButtonImage]) {
        // Shift text field to the right:
        CGRect textContainerFrame = [[self textContainer] frame];
        textContainerFrame.size.width -= kUtilityButtonWidth + kHorizontalPadding;
        textContainerFrame.origin.x   += kUtilityButtonWidth + kHorizontalPadding;
        [[self textContainer] setFrame:textContainerFrame];

        // Insert utility button:
        UIButton *utilityButton = [self utilityButton];
        CGRect utilityButtonFrame = [utilityButton frame];
        utilityButtonFrame.origin.x = kHorizontalPadding;
        utilityButtonFrame.origin.y = [self frame].size.height - kUtilityButtonHeight - kBottomPadding;
        [utilityButton setFrame:utilityButtonFrame];
        [self addSubview:utilityButton];
    } else {
        // Shift text field to the left:
        CGRect textContainerFrame = [[self textContainer] frame];
        textContainerFrame.size.width += kUtilityButtonWidth + kHorizontalPadding;
        textContainerFrame.origin.x   -= kUtilityButtonWidth + kHorizontalPadding;
        [[self textContainer] setFrame:textContainerFrame];

        // Remove utility button:
        [[self utilityButton] removeFromSuperview];
    }
}

- (UIImage *)utilityButtonImage {
    return [[self utilityButton] imageForState:UIControlStateNormal];
}

- (void)setUtilityButtonImage:(UIImage *)image {
    [[self utilityButton] setImage:image forState:UIControlStateNormal];
    [self updateUtilityButtonVisibility];
}

@synthesize enabled = _enabled;
- (void)setEnabled:(BOOL)enabled {
    if (enabled != _enabled) {
        _enabled = enabled;
        [[self textView] setUserInteractionEnabled:enabled];
        [self updateButtonEnabled];
        [[self utilityButton] setEnabled:enabled];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [self hidePlaceholderIfNeeded];
    [self resizeTextViewIfNeededAnimated:YES];
    [self scrollToCaretIfNeeded];
    [self updateCharCountLabel];
    [self updateButtonEnabled];
}

#pragma mark - Helpers

- (void)hidePlaceholderIfNeeded {
    BOOL shouldHide = ![[[self textView] text] isEqualToString:@""];
    [[self placeholderLabel] setHidden:shouldHide];
}

// 1. Several cases need to be distinguished when text is added:
//    a) line count is below max and lines are added such that the max threshold is not exceeded
//    b) same as previous, but max threshold is exceeded
//    c) line count is over or at max and one or several lines are added
// 2. Same goes for the other way around, when text is removed:
//    a) line count is <= max and lines are removed
//    b) line count is above max and lines are removed such that the lines count get below max-1
//    c) same as previous, but line count at the end is >= max
- (void)resizeTextViewIfNeededAnimated:(BOOL)animated {
    // Only resize if we're place in a view. Resizing will be done once inside
    // a view.
    if (![self superview])
        return;

    CGFloat textHeight         = [self textHeight];
    CGFloat maxViewHeight      = [self maxHeight];
    CGFloat previousTextHeight = [self previousTextHeight];
    CGFloat textHeightDelta    = textHeight - previousTextHeight;

    // This is actually not needed for the scrolling behavior itself since
    // scrolling doesn't work when there's nothing to scroll. It is used to
    // force the autocorrection popup to be shown above and not below the text
    // where it gets clipped.
    [[self textView] setScrollEnabled:(textHeight > maxViewHeight)];

    // NOTE: Continue even if the actual view height won't change because of max
    //       or min height constraints in order to ensure the correct content
    //       offset when a text line is added or removed.
    if (!textHeightDelta && [self bounds].size.height == maxViewHeight)
        return;

    [self setPreviousTextHeight:textHeight];
    CGFloat newViewHeight = MAX(MIN(textHeight, maxViewHeight), PHFComposeBarViewInitialHeight);
    CGFloat viewHeightDelta = newViewHeight - [self bounds].size.height;

    // Set the content offset so that no empty lines are shown at the end of the
    // text view:
    CGFloat yOffset = MAX(textHeight - maxViewHeight, 0.0f);
    void (^scroll)(void) = NULL;
    if (yOffset != [[self textView] contentOffset].y)
         scroll = ^{ [(PHFComposeBarTextView *)[self textView] PHFSetContentOffset:CGPointMake(0.0f, yOffset)]; };

    if (viewHeightDelta) {
        CGFloat animationDurationFactor = animated ? 1.0f : 0.0f;

        CGRect frameBegin     = [self frame];
        CGRect frameEnd       = frameBegin;
        frameEnd.size.height += viewHeightDelta;
        if ([self autoAdjustTopOffset])
            frameEnd.origin.y -= viewHeightDelta;

        void (^animation)(void) = ^{
            [self setFrame:frameEnd];
        };

        NSDictionary *willChangeUserInfo = @{
            PHFComposeBarViewFrameBeginUserInfoKey        : [NSValue valueWithCGRect:frameBegin],
            PHFComposeBarViewFrameEndUserInfoKey          : [NSValue valueWithCGRect:frameEnd],
            PHFComposeBarViewAnimationDurationUserInfoKey : @(kResizeAnimationDuration * animationDurationFactor),
            PHFComposeBarViewAnimationCurveUserInfoKey    : [NSNumber numberWithInt:kResizeAnimationCurve]
        };

        NSDictionary *didChangeUserInfo = @{
            PHFComposeBarViewFrameBeginUserInfoKey        : [NSValue valueWithCGRect:frameBegin],
            PHFComposeBarViewFrameEndUserInfoKey          : [NSValue valueWithCGRect:frameEnd],
        };

        [self postNotification:PHFComposeBarViewWillChangeFrameNotification userInfo:willChangeUserInfo];

        if (animated) {
            [UIView animateWithDuration:kResizeAnimationDuration * animationDurationFactor
                                  delay:kResizeAnimationDelay
                                options:kResizeAnimationCurve
                             animations:animation
                             completion:^(BOOL _){
                                 [self postNotification:PHFComposeBarViewDidChangeFrameNotification userInfo:didChangeUserInfo];
                             }];
        } else {
            animation();
            [self postNotification:PHFComposeBarViewDidChangeFrameNotification userInfo:didChangeUserInfo];
        }

        if (scroll)
            scroll();
    } else {
        [UIView animateWithDuration:kResizeAnimationDuration
                              delay:kResizeAnimationDelay
                            options:kResizeAnimationCurve
                         animations:scroll
                         completion:NULL];
    }
}

- (void)postNotification:(NSString *)name userInfo:(NSDictionary *)userInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:name
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)scrollToCaretIfNeeded {
    if (![self superview])
        return;

    UITextRange *selectedTextRange = [[self textView] selectedTextRange];
    if ([selectedTextRange isEmpty]) {
        UITextPosition *position = [selectedTextRange start];
        CGPoint offset = [[self textView] contentOffset];
        CGFloat relativeCaretY = [[self textView] caretRectForPosition:position].origin.y - kCaretYOffset - offset.y;
        CGFloat offsetYDelta = 0.0f;
        // Caret is above visible part of text view:
        if (relativeCaretY < 0.0f) {
            offsetYDelta = relativeCaretY;
        }
        // Caret is in or below visible part of text view:
        else if (relativeCaretY > 0.0f) {
            CGFloat maxY = [self bounds].size.height - PHFComposeBarViewInitialHeight;
            // Caret is below visible part of text view:
            if (relativeCaretY > maxY)
                offsetYDelta = relativeCaretY - maxY;
        }

        if (offsetYDelta) {
            offset.y += offsetYDelta;
            [UIView animateWithDuration:kScrollAnimationDuration
                                  delay:kScrollAnimationDelay
                                options:kScrollAnimationCurve
                             animations:^{
                                 [(PHFComposeBarTextView *)[self textView] PHFSetContentOffset:offset];
                             }
                             completion:NULL];
        }
    }
}

- (CGFloat)textHeight {
    // Sometimes when the text is empty, the contentSize is larger than actually
    // needed.
    if ([[[self textView] text] isEqualToString:@""])
        return PHFComposeBarViewInitialHeight;
    else
        return [[self textView] contentSize].height + kTextViewToSuperviewHeightDelta;
}

@synthesize previousTextHeight = _previousTextHeight;
- (CGFloat)previousTextHeight {
    if (!_previousTextHeight)
        _previousTextHeight = [self bounds].size.height;

    return _previousTextHeight;
}

- (void)updateCharCountLabel {
    if ([self maxCharCount]) {
        NSString *text = [NSString stringWithFormat:@"%d/%d", [[[self textView] text] length], [self maxCharCount]];
        [[self charCountLabel] setText:text];
    }
}

- (void)updateButtonEnabled {
    BOOL enabled = [self isEnabled] && [[[self textView] text] length] > 0;
    [[self button] setEnabled:enabled];
    [[[self button] titleLabel] setAlpha:(enabled ? 1.0f : 0.5f)];
}

- (void)didPressButton {
    if ([[self delegate] respondsToSelector:@selector(textBarViewDidPressButton:)])
        [[self delegate] textBarViewDidPressButton:self];
}

- (void)didPressUtilityButton {
    if ([[self delegate] respondsToSelector:@selector(textBarViewDidPressUtilityButton:)])
        [[self delegate] textBarViewDidPressUtilityButton:self];
}

#pragma mark - Accessors

@synthesize textContainer = _textContainer;
// Returns the text container which contains the actual text view, the
// placeholder and the image view that contains the text field image.
- (UIButton *)textContainer {
    if (!_textContainer) {
        CGRect textContainerFrame = CGRectMake(kHorizontalPadding,
                                               kTopPadding,
                                               [self bounds].size.width - kHorizontalPadding * 3 - kButtonWidth,
                                               [self bounds].size.height - kTopPadding - kBottomPadding);
        _textContainer = [UIButton buttonWithType:UIButtonTypeCustom];
        [_textContainer setFrame:textContainerFrame];
        [_textContainer setClipsToBounds:YES];
        [_textContainer setBackgroundColor:[UIColor colorWithWhite:0.96f alpha:1.0f]];
        [_textContainer setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

        CGRect textViewFrame = textContainerFrame;
        textViewFrame.size.width  -= 2.0f * kTextViewSidePadding;
        textViewFrame.size.height -= 1.0f; // Neglect the white shadow pixel
        textViewFrame.origin.x = kTextViewSidePadding;
        textViewFrame.origin.y = kTextViewTopPadding;
        [[self textView] setFrame:textViewFrame];
        [_textContainer addSubview:[self textView]];

        CGRect placeholderFrame = CGRectMake(kPlaceholderSidePadding,
                                             kPlaceholderTopPadding,
                                             textContainerFrame.size.width - 2 * kPlaceholderSidePadding,
                                             kPlaceholderHeight);
        [[self placeholderLabel] setFrame:placeholderFrame];
        [_textContainer addSubview:[self placeholderLabel]];

        CGRect textFieldImageFrame = textContainerFrame;
        textFieldImageFrame.origin = CGPointZero;
        [[self textFieldImageView] setFrame:textFieldImageFrame];
        [_textContainer addSubview:[self textFieldImageView]];

        [_textContainer addTarget:[self textView] action:@selector(becomeFirstResponder) forControlEvents:UIControlEventTouchUpInside];
    }

    return _textContainer;
}

@synthesize textView = _textView;
- (UITextView *)textView {
    if (!_textView) {
        _textView = [PHFComposeBarTextView new];
        // Setting the bottom inset to -10 has the effect that no scroll area is
        // available which also prevents scrolling when the frame is big enough.
        [_textView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, -10.0f, 0.0f)];
        // The scrolling enabling will be handled in _resizeTextViewIfNeeded.
        // See comment there about why this is needed.
        [_textView setScrollEnabled:NO];
        [_textView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
        // The view will be clipped by a parent view.
        [_textView setClipsToBounds:NO];
        [_textView setScrollIndicatorInsets:UIEdgeInsetsMake(-kTextViewTopPadding + kTextViewScrollInsetTop,
                                                             0.0f,
                                                             kTextViewScrollInsetBottom,
                                                             -kTextViewSidePadding)];
        [_textView setBackgroundColor:[UIColor clearColor]];
        [_textView setFont:[UIFont systemFontOfSize:16.0f]];
        [self setupDelegateChainForTextView];
    }

    return _textView;
}

@synthesize placeholderLabel = _placeholderLabel;
- (UILabel *)placeholderLabel {
    if (!_placeholderLabel) {
        _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_placeholderLabel setBackgroundColor:[UIColor clearColor]];
        [_placeholderLabel setEnabled:NO];
        [_placeholderLabel setFont:[UIFont systemFontOfSize:16.0f]];
        [_placeholderLabel setTextColor:[UIColor colorWithWhite:0.7f alpha:1.0f]];
        [_placeholderLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_placeholderLabel setAdjustsFontSizeToFitWidth:YES];
        [_placeholderLabel setMinimumFontSize:[UIFont smallSystemFontSize]];
    }

    return _placeholderLabel;
}

@synthesize backgroundView = _backgroundView;
- (UIImageView *)backgroundView {
    if (!_backgroundView) {
        UIImage *backgroundImage = [[UIImage imageNamed:@"PHFComposeBarView-Background"] stretchableImageWithLeftCapWidth:0 topCapHeight:18];
        _backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
        [_backgroundView setFrame:[self bounds]];
        [_backgroundView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    }

    return _backgroundView;
}

@synthesize textFieldImageView = _textFieldImageView;
- (UIImageView *)textFieldImageView {
    if (!_textFieldImageView) {
        UIImage *textBackgroundImage = [[UIImage imageNamed:@"PHFComposeBarView-TextField"] stretchableImageWithLeftCapWidth:13 topCapHeight:12];
        _textFieldImageView = [[UIImageView alloc] initWithImage:textBackgroundImage];
        [_textFieldImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    }

    return _textFieldImageView;
}

@synthesize charCountLabel = _charCountLabel;
- (UILabel *)charCountLabel {
    if (!_charCountLabel) {
        CGRect frame = CGRectMake([self bounds].size.width - kHorizontalPadding - kButtonWidth,
                                  kTopPadding + 2.0f,
                                  kButtonWidth,
                                  20.0f);
        _charCountLabel = [[UILabel alloc] initWithFrame:frame];
        [_charCountLabel setHidden:![self maxCharCount]];
        [_charCountLabel setTextAlignment:UITextAlignmentCenter];
        [_charCountLabel setBackgroundColor:[UIColor clearColor]];
        [_charCountLabel setFont:[UIFont boldSystemFontOfSize:[UIFont smallSystemFontSize]]];
        [_charCountLabel setTextColor:[UIColor colorWithWhite:0.5f alpha:1.0f]];
        [_charCountLabel setShadowColor:[UIColor colorWithWhite:1.0f alpha:0.8f]];
        [_charCountLabel setShadowOffset:CGSizeMake(0.0f, 1.0f)];
        [_charCountLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin];
    }

    return _charCountLabel;
}

@synthesize button = _button;
- (UIButton *)button {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = CGRectMake([self bounds].size.width - kHorizontalPadding - kButtonWidth,
                                  [self bounds].size.height - kBottomPadding - kButtonHeight,
                                  kButtonWidth,
                                  kButtonHeight);
        [_button setFrame:frame];
        [_button setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin];
        [_button setTitle:[self buttonTitle] forState:UIControlStateNormal];
        [_button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_button addTarget:self action:@selector(didPressButton) forControlEvents:UIControlEventTouchUpInside];

        NSString *imageName        = @"PHFComposeBarView-Button";
        NSString *imageNamePressed = [imageName stringByAppendingString:@"Pressed"];
        UIImage *backgroundImagePressed = [[UIImage imageNamed:imageNamePressed] stretchableImageWithLeftCapWidth:14 topCapHeight:0];
        UIImage *backgroundImage        = [[UIImage imageNamed:imageName]        stretchableImageWithLeftCapWidth:14 topCapHeight:0];
        UIButton *button = [self button];
        [button setBackgroundImage:backgroundImage        forState:UIControlStateNormal];
        [button setBackgroundImage:backgroundImage        forState:UIControlStateDisabled];
        [button setBackgroundImage:backgroundImagePressed forState:UIControlStateHighlighted];

        UILabel *label = [_button titleLabel];
        [label setFont:[UIFont boldSystemFontOfSize:16.0f]];

        CALayer *layer = [label layer];
        [layer setShadowColor:[[UIColor blackColor] CGColor]];
        [layer setShadowOpacity:0.3f];
        [layer setShadowOffset:CGSizeMake(0.0f, -1.0f)];
        [layer setShadowRadius:0.0f];
        // Rasterization causes the shadow to not shine through the text when
        // the alpha is < 1:
        [layer setShouldRasterize:YES];
    }

    return _button;
}

@synthesize utilityButton = _utilityButton;
- (UIButton *)utilityButton {
    if (!_utilityButton) {
        _utilityButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_utilityButton setAutoresizingMask:UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin];
        [_utilityButton setFrame:CGRectMake(0.0f,
                                            [self bounds].size.height - kUtilityButtonHeight,
                                            kUtilityButtonWidth,
                                            kUtilityButtonHeight)];
        [_utilityButton addTarget:self action:@selector(didPressUtilityButton) forControlEvents:UIControlEventTouchUpInside];
        [_utilityButton setContentEdgeInsets:UIEdgeInsetsMake(0.0f, 0.0f, 1.0f, 0.0f)];

        UIImage *backgroundImage = [UIImage imageNamed:@"PHFComposeBarView-UtilityButton"];
        [_utilityButton setBackgroundImage:backgroundImage forState:UIControlStateNormal];
        [_utilityButton setBackgroundImage:backgroundImage forState:UIControlStateDisabled];

        CALayer *layer = [[_utilityButton imageView] layer];
        [layer setMasksToBounds:NO];
        [layer setShadowColor:[[UIColor blackColor] CGColor]];
        [layer setShadowOpacity:0.5f];
        [layer setShadowOffset:CGSizeMake(0.0f, -0.5f)];
        [layer setShadowRadius:0.5f];
    }

    return _utilityButton;
}

@end
