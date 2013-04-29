#import "PHFComposeBarView.h"

#import <QuartzCore/QuartzCore.h>
#import <PHFDelegateChain/PHFDelegateChain.h>

#import "PHFComposeBarTextView.h"

#pragma mark - Extern Constants

CGFloat const PHFComposeBarViewInitialHeight = 40;

NSString * const PHFComposeBarViewWillChangeFrameNotification  = @"PHFComposeBarViewWillChangeFrame";
NSString * const PHFComposeBarViewFrameBeginUserInfoKey        = @"PHFComposeBarViewFrameBegin";
NSString * const PHFComposeBarViewFrameEndUserInfoKey          = @"PHFComposeBarViewFrameEnd";
NSString * const PHFComposeBarViewAnimationDurationUserInfoKey = @"PHFComposeBarViewAnimationDuration";
NSString * const PHFComposeBarViewAnimationCurveUserInfoKey    = @"PHFComposeBarViewAnimationCurve";

CGFloat const kHorizontalPadding         = 6;
CGFloat const kTopPadding                = 8;
CGFloat const kBottomPadding             = 5;
CGFloat const kTextViewRightPadding      = 2;
CGFloat const kTextViewLeftPadding       = 2;
CGFloat const kTextViewTopPadding        = -6;
CGFloat const kTextViewScrollInsetTop    = 6;
CGFloat const kTextViewScrollInsetBottom = 2;
CGFloat const kButtonWidth               = 58;
CGFloat const kButtonHeight              = 27;
CGFloat const kUtilityButtonWidth        = 26;
CGFloat const kUtilityButtonHeight       = 27;
CGFloat const kCaretYOffset             = 9;

#pragma mark - Intern Constants

CGRect const kDefaultFrame = {0, 0, 320, PHFComposeBarViewInitialHeight};

UIViewAnimationOptions const kResizeAnimationCurve = UIViewAnimationOptionCurveEaseInOut;
UIViewAnimationOptions const kScrollAnimationCurve = UIViewAnimationOptionCurveEaseInOut;
NSTimeInterval const kResizeAnimationDuration    = 0.1;
NSTimeInterval const kScrollAnimationDuration    = 0.1;
NSTimeInterval const kResizeAnimationDelay       = 0;
NSTimeInterval const kScrollAnimationDelay       = 0.1;

static CGFloat kTextViewLineHeight;
static CGFloat kTextViewFirstLineHeight;
static CGFloat kTextViewToSuperviewHeightDelta;

@interface PHFComposeBarView ()

- (void)setup;
- (void)resizeTextViewIfNeeded;
- (void)scrollToCaretIfNeeded;
/**
 Returns the height that would be required to show the full text without the
 need for scrolling.
 */
- (CGFloat)textHeight;
- (void)updateCharCountLabel;
- (void)updateButtonEnabled;
- (void)didPressButton;

@property (strong, nonatomic, readonly) UIButton *textContainer;
@property (strong, nonatomic, readonly) UIImageView *backgroundView;
@property (strong, nonatomic, readonly) UIImageView *textFieldImageView;
@property (strong, nonatomic, readonly) UILabel *charCountLabel;
@property (strong, nonatomic, readonly) UIButton *button;
@property (strong, nonatomic, readonly) UIButton *utilityButton;
@property (assign, nonatomic) CGFloat previousTextHeight;
@property (strong, nonatomic) PHFDelegateChain *delegateChain;

@end

@implementation PHFComposeBarView

- (void)setup {
    _utilityButtonHidden = YES;

    [self addSubview:[self backgroundView]];
    [self addSubview:[self charCountLabel]];
    [self addSubview:[self button]];
    [self addSubview:[self textContainer]];

    [self setAutoAdjustTopOffset:YES];
}

- (void)setAutoAdjustTopOffset:(BOOL)autoAdjustTopOffset {
    _autoAdjustTopOffset = autoAdjustTopOffset;

    if (autoAdjustTopOffset)
        [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin];
    else
        [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setup];
        [self setFrame:frame];
        [self setEnabled:YES];

        // Some constants that depend on view attributes:
        if (!kTextViewLineHeight || !kTextViewFirstLineHeight || !kTextViewToSuperviewHeightDelta) {
            kTextViewLineHeight             = [[[self textView] font] lineHeight];
            kTextViewFirstLineHeight        = kTextViewLineHeight + [[[self textView] font] pointSize];
            kTextViewToSuperviewHeightDelta = PHFComposeBarViewInitialHeight - kTextViewFirstLineHeight;
        }
    }

    return self;
}

- (id)init {
    return [self initWithFrame:kDefaultFrame];
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

// Disabling the button before insertion into view will cause it to look
// disabled but it will in fact still be tappable. To work around this issue,
// update the enabled state once inserted into view.
- (void)didMoveToSuperview {
    [self updateButtonEnabled];
}

- (void)layoutSubviews {
    NSLog(@"Layout");
    [super layoutSubviews];
    [self resizeTextViewIfNeeded];
}

- (void)setupDelegateChainForTextView {
    PHFDelegateChain *delegateChain = [PHFDelegateChain delegateChainWithObjects:self, [self delegate], nil];
    [self setDelegateChain:delegateChain];
    [[self textView] setDelegate:(id<UITextViewDelegate>)delegateChain];
}

#pragma mark - Public Methods

- (CGFloat)maxLinesCount {
    CGFloat normalizedHeight = [self maxHeight] - PHFComposeBarViewInitialHeight + kTextViewLineHeight;
    return normalizedHeight / kTextViewLineHeight;
}
- (void)setMaxLinesCount:(CGFloat)maxLinesCount {
    CGFloat maxTextHeight = maxLinesCount * kTextViewLineHeight;
    CGFloat maxHeight     = maxTextHeight - kTextViewLineHeight + PHFComposeBarViewInitialHeight;
    [self setMaxHeight:maxHeight];
}

@synthesize maxHeight = _maxHeight;
- (CGFloat)maxHeight {
    if (!_maxHeight)
        _maxHeight = 200;

    return _maxHeight;
}
- (void)setMaxHeight:(CGFloat)maxHeight {
    _maxHeight = maxHeight;
    [self resizeTextViewIfNeeded];
    [self scrollToCaretIfNeeded];
}

@synthesize maxCharCount = _maxCharCount;
- (void)setMaxCharCount:(NSUInteger)count {
    if (_maxCharCount != count) {
        _maxCharCount = count;
        [[self charCountLabel] setHidden:!_maxCharCount];
    }
}

@synthesize placeholder = _placeholder;
- (void)setPlaceholder:(NSString *)placeholder {
    if (_placeholder != placeholder) {
        _placeholder = placeholder;
        [[self placeholderLabel] setText:placeholder];
    }
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

@synthesize utilityButtonHidden = _utilityButtonHidden;
- (void)setUtilityButtonHidden:(BOOL)hidden {
    if (_utilityButtonHidden != hidden) {
        _utilityButtonHidden = hidden;
        if (hidden) {
            // Shift text field to the left:
            CGRect textContainerFrame = [[self textContainer] frame];
            textContainerFrame.size.width += kUtilityButtonWidth + kHorizontalPadding;
            textContainerFrame.origin.x   -= kUtilityButtonWidth + kHorizontalPadding;
            [[self textContainer] setFrame:textContainerFrame];

            // Remove utility button:
            [[self utilityButton] removeFromSuperview];
        } else if (!hidden) {
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
        }
    }
}

- (UIImage *)utilityButtonImage {
    return [[self utilityButton] imageForState:UIControlStateNormal];
}

- (void)setUtilityButtonImage:(UIImage *)image {
    [[self utilityButton] setImage:image forState:UIControlStateNormal];
}

@synthesize enabled = _enabled;
- (void)setEnabled:(BOOL)enabled {
    if (enabled != _enabled) {
        _enabled = enabled;
        [[self button] setEnabled:enabled];
    }
}

#pragma mark - UITextViewDelegate


- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    if (![self isEnabled])
        return NO;
    else if ([[self delegate] respondsToSelector:@selector(textViewShouldBeginEditing:)])
        return [[self delegate] textViewShouldBeginEditing:textView];
    else
        return YES;
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    if ([[self delegate] respondsToSelector:@selector(textViewShouldEndEditing:)])
        return [[self delegate] textViewShouldEndEditing:textView];
    return YES;
}

// Limit the text length.
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    BOOL shouldChange = YES;

    if ([[self delegate] respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)])
        shouldChange = [[self delegate] textView:textView shouldChangeTextInRange:range replacementText:text];

    if (shouldChange && [self maxCharCount]) {
        NSUInteger newLength = [[textView text] length] + [text length] - range.length;
        shouldChange = newLength <= [self maxCharCount];
    }

    return shouldChange;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self hidePlaceholderIfNeeded];
    [self resizeTextViewIfNeeded];
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
- (void)resizeTextViewIfNeeded {
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
    CGFloat yOffset = MAX(textHeight - maxViewHeight, 0);
    void (^scroll)(void) = NULL;
    if (yOffset != [[self textView] contentOffset].y)
         scroll = ^{ [(PHFComposeBarTextView *)[self textView] PHFSetContentOffset:CGPointMake(0, yOffset)]; };

    if (viewHeightDelta) {
        CGRect frameBegin     = [self frame];
        CGRect frameEnd       = frameBegin;
        frameEnd.size.height += viewHeightDelta;
        if ([self autoAdjustTopOffset])
            frameEnd.origin.y -= viewHeightDelta;

        NSDictionary *userInfo = @{PHFComposeBarViewFrameBeginUserInfoKey: [NSValue valueWithCGRect:frameBegin],
                                  PHFComposeBarViewFrameEndUserInfoKey: [NSValue valueWithCGRect:frameEnd],
                                  PHFComposeBarViewAnimationDurationUserInfoKey: @(kResizeAnimationDuration),
                                  PHFComposeBarViewAnimationCurveUserInfoKey: [NSNumber numberWithInt:kResizeAnimationCurve]};
        [[NSNotificationCenter defaultCenter] postNotificationName:PHFComposeBarViewWillChangeFrameNotification
                                                            object:self
                                                          userInfo:userInfo];

        [UIView animateWithDuration:kResizeAnimationDuration
                              delay:kResizeAnimationDelay
                            options:kResizeAnimationCurve
                         animations:^{ [self setFrame:frameEnd]; }
                         completion:NULL];
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

- (void)scrollToCaretIfNeeded {
    // Only works in iOS 5:
    if ([[self textView] conformsToProtocol:@protocol(UITextInput)]) {
        UITextPosition *position = [[[self textView] selectedTextRange] start];
        if (position) {
            CGPoint offset = [[self textView] contentOffset];
            CGFloat relativeCaretY = [[self textView] caretRectForPosition:position].origin.y - kCaretYOffset - offset.y;
            CGFloat offsetYDelta = 0;
            // Caret is above visible part of text view:
            if (relativeCaretY < 0) {
                offsetYDelta = relativeCaretY;
            }
            // Caret is in or below visible part of text view:
            else if (relativeCaretY > 0) {
                CGFloat maxY = [self bounds].size.height - PHFComposeBarViewInitialHeight;
                // Caret is below visible part of text view:
                if (relativeCaretY > maxY)
                    offsetYDelta = relativeCaretY - maxY;
            }

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
        _previousTextHeight = PHFComposeBarViewInitialHeight;

    return _previousTextHeight;
}

- (void)updateCharCountLabel {
    if ([self maxCharCount]) {
        NSString *text = [NSString stringWithFormat:@"%d/%d", [[[self textView] text] length], [self maxCharCount]];
        [[self charCountLabel] setText:text];
    }
}

- (void)updateButtonEnabled {
    BOOL enabled = [[[self textView] text] length] > 0;
    [[self button] setEnabled:enabled];
    [[[self button] titleLabel] setAlpha:(enabled ? 1 : 0.5)];
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
                                               kDefaultFrame.size.width - kHorizontalPadding * 3 - kButtonWidth,
                                               kDefaultFrame.size.height - kTopPadding - kBottomPadding);
        _textContainer = [UIButton buttonWithType:UIButtonTypeCustom];
        [_textContainer setFrame:textContainerFrame];
        [_textContainer setClipsToBounds:YES];
        [_textContainer setBackgroundColor:[UIColor colorWithWhite:0.96 alpha:1]];
        [_textContainer setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

        CGRect textViewFrame = textContainerFrame;
        textViewFrame.size.width  -= kTextViewRightPadding + kTextViewLeftPadding;
        textViewFrame.size.height -= 1; // Neglect the white shadow pixel
        textViewFrame.origin.x = kTextViewLeftPadding;
        textViewFrame.origin.y = kTextViewTopPadding;
        [[self textView] setFrame:textViewFrame];
        [_textContainer addSubview:[self textView]];

        CGRect placeholderFrame = textContainerFrame;
        placeholderFrame.origin.x = 12;
        placeholderFrame.origin.y = 0;
        placeholderFrame.size.height -= 2;
        placeholderFrame.size.width -= 12 * 2;
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
        [_textView setContentInset:UIEdgeInsetsMake(0, 0, -10, 0)];
        // The scrolling enabling will be handled in _resizeTextViewIfNeeded.
        // See comment there about why this is needed.
        [_textView setScrollEnabled:NO];
        [_textView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
        // The view will be clipped by a parent view.
        [_textView setClipsToBounds:NO];
        [_textView setScrollIndicatorInsets:UIEdgeInsetsMake(-kTextViewTopPadding + kTextViewScrollInsetTop,
                                                             0,
                                                             kTextViewScrollInsetBottom,
                                                             -kTextViewRightPadding)];
        [_textView setBackgroundColor:[UIColor clearColor]];
        [_textView setFont:[UIFont systemFontOfSize:16]];
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
        [_placeholderLabel setText:[self placeholder]];
        [_placeholderLabel setFont:[UIFont systemFontOfSize:16]];
        [_placeholderLabel setTextColor:[UIColor colorWithWhite:0.7 alpha:1]];
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
        [_backgroundView setFrame:kDefaultFrame];
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
        CGRect frame = CGRectMake(kDefaultFrame.size.width - kHorizontalPadding - kButtonWidth,
                                  kTopPadding + 2,
                                  kButtonWidth,
                                  20);
        _charCountLabel = [[UILabel alloc] initWithFrame:frame];
        [_charCountLabel setHidden:![self maxCharCount]];
        [_charCountLabel setTextAlignment:UITextAlignmentCenter];
        [_charCountLabel setBackgroundColor:[UIColor clearColor]];
        [_charCountLabel setFont:[UIFont boldSystemFontOfSize:[UIFont smallSystemFontSize]]];
        [_charCountLabel setTextColor:[UIColor colorWithWhite:0.5 alpha:1]];
        [_charCountLabel setShadowColor:[UIColor colorWithWhite:1 alpha:0.8]];
        [_charCountLabel setShadowOffset:CGSizeMake(0, 1)];
        [_charCountLabel setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleBottomMargin];
    }

    return _charCountLabel;
}

@synthesize button = _button;
- (UIButton *)button {
    if (!_button) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = CGRectMake(kDefaultFrame.size.width - kHorizontalPadding - kButtonWidth,
                                  kTopPadding,
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
        [label setFont:[UIFont boldSystemFontOfSize:16]];

        CALayer *layer = [label layer];
        [layer setShadowColor:[[UIColor blackColor] CGColor]];
        [layer setShadowOpacity:0.3];
        [layer setShadowOffset:CGSizeMake(0, -1)];
        [layer setShadowRadius:0];
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
        [_utilityButton setFrame:CGRectMake(0, 0, kUtilityButtonWidth, kUtilityButtonHeight)];
        [_utilityButton addTarget:self action:@selector(didPressUtilityButton) forControlEvents:UIControlEventTouchUpInside];
        [_utilityButton setContentEdgeInsets:UIEdgeInsetsMake(0, 0, 1, 0)];

        UIImage *backgroundImage = [UIImage imageNamed:@"PHFComposeBarView-UtilityButton"];
        [_utilityButton setBackgroundImage:backgroundImage forState:UIControlStateNormal];

        CALayer *layer = [[_utilityButton imageView] layer];
        [layer setMasksToBounds:NO];
        [layer setShadowColor:[[UIColor blackColor] CGColor]];
        [layer setShadowOpacity:0.5];
        [layer setShadowOffset:CGSizeMake(0, -0.5)];
        [layer setShadowRadius:0.5];
    }

    return _utilityButton;
}

@end
