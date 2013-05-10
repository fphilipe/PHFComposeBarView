#import "ViewController.h"

@interface ViewController ()
@property (readonly, nonatomic) UIView *container;
@property (readonly, nonatomic) PHFComposeBarView *composeBarView;
@property (readonly, nonatomic) UITextView *textView;
@end

CGRect const kInitialViewFrame = { 0.0f, 0.0f, 320.0f, 480.0f };

@implementation ViewController

- (id)init {
    self = [super init];

    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(composeBarViewWillChangeFrame:)
                                                     name:PHFComposeBarViewWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillToggle:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillToggle:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:PHFComposeBarViewWillChangeFrameNotification
                                                  object:nil];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:kInitialViewFrame];
    [view setBackgroundColor:[UIColor colorWithHue:220/360.0 saturation:0.08 brightness:0.93 alpha:1]];

    UIView *container = [self container];
    [container addSubview:[self textView]];
    [container addSubview:[self composeBarView]];
    [view addSubview:container];

    [self setView:view];
}

- (void)keyboardWillToggle:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval duration;
    UIViewAnimationCurve animationCurve;
    CGRect startFrame;
    CGRect endFrame;
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey]    getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey]        getValue:&startFrame];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]          getValue:&endFrame];

    NSInteger signCorrection = 1;
    if (startFrame.origin.y < 0 || startFrame.origin.x < 0 || endFrame.origin.y < 0 || endFrame.origin.x < 0)
       signCorrection = -1;

    CGFloat widthChange  = (endFrame.origin.x - startFrame.origin.x) * signCorrection;
    CGFloat heightChange = (endFrame.origin.y - startFrame.origin.y) * signCorrection;

    CGFloat sizeChange = UIInterfaceOrientationIsLandscape([self interfaceOrientation]) ? widthChange : heightChange;

    CGRect newContainerFrame = [[self container] frame];
    newContainerFrame.size.height += sizeChange;

    CGFloat offsetY = MAX(0.0f, [[self textView] contentSize].height - [[self textView] frame].size.height - sizeChange);
    CGPoint newTextViewContentOffset = CGPointMake(0, offsetY);

    [UIView animateWithDuration:duration
                          delay:0
                        options:animationCurve|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [[self container] setFrame:newContainerFrame];
                     }
                     completion:NULL];
    [[self textView] setContentOffset:newTextViewContentOffset animated:YES];
}

- (void)composeBarViewWillChangeFrame:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval duration;
    UIViewAnimationCurve animationCurve;
    CGRect startFrame;
    CGRect endFrame;
    [[userInfo objectForKey:PHFComposeBarViewAnimationDurationUserInfoKey] getValue:&duration];
    [[userInfo objectForKey:PHFComposeBarViewAnimationCurveUserInfoKey]    getValue:&animationCurve];
    [[userInfo objectForKey:PHFComposeBarViewFrameBeginUserInfoKey]        getValue:&startFrame];
    [[userInfo objectForKey:PHFComposeBarViewFrameEndUserInfoKey]          getValue:&endFrame];

    CGFloat heightChange = endFrame.size.height - startFrame.size.height;

    CGRect newTextViewFrame = [[self textView] frame];
    newTextViewFrame.size.height -= heightChange;

    CGFloat offsetY = MAX(0.0f, [[self textView] contentSize].height - newTextViewFrame.size.height);
    CGPoint newTextViewContentOffset = CGPointMake(0, offsetY);

    [UIView animateWithDuration:duration
                          delay:0
                        options:animationCurve|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [[self textView] setFrame:newTextViewFrame];
                         [[self textView] setContentOffset:newTextViewContentOffset];
                     }
                     completion:NULL];
}

- (void)composeBarViewDidPressButton:(PHFComposeBarView *)composeBarView {
    NSString *text = [NSString stringWithFormat:@"Main button pressed. Text:\n%@", [composeBarView text]];
    [self appendTextToTextView:text];
    [composeBarView setText:@""];
    [composeBarView resignFirstResponder];
}

- (void)composeBarViewDidPressUtilityButton:(PHFComposeBarView *)composeBarView {
    [self appendTextToTextView:@"Utility button pressed"];
}

- (void)composeBarView:(PHFComposeBarView *)composeBarView
   willChangeFromFrame:(CGRect)startFrame
               toFrame:(CGRect)endFrame
              duration:(NSTimeInterval)duration
        animationCurve:(UIViewAnimationCurve)animationCurve
{
    [self appendTextToTextView:[NSString stringWithFormat:@"Height changing by %d", (NSInteger)(endFrame.size.height - startFrame.size.height)]];
}

- (void)composeBarView:(PHFComposeBarView *)composeBarView
    didChangeFromFrame:(CGRect)startFrame
               toFrame:(CGRect)endFrame
{
    [self appendTextToTextView:@"Height changed"];
}

- (void)appendTextToTextView:(NSString *)text {
    NSString *newText = [[[self textView] text] stringByAppendingFormat:@"\n\n%@", text];
    [[self textView] setText:newText];
    [self scrollTextViewToBottom];
}

- (void)scrollTextViewToBottom {
    CGFloat offsetY = MAX(0.0f, [[self textView] contentSize].height - [[self textView] frame].size.height);
    CGPoint newTextViewContentOffset = CGPointMake(0, offsetY);
    [[self textView] setContentOffset:newTextViewContentOffset animated:YES];
}

@synthesize container = _container;
- (UIView *)container {
    if (!_container) {
        _container = [[UIView alloc] initWithFrame:kInitialViewFrame];
        [_container setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    }

    return _container;
}

@synthesize composeBarView = _composeBarView;
- (PHFComposeBarView *)composeBarView {
    if (!_composeBarView) {
        CGRect frame = CGRectMake(0.0f,
                                  kInitialViewFrame.size.height - PHFComposeBarViewInitialHeight,
                                  kInitialViewFrame.size.width,
                                  PHFComposeBarViewInitialHeight);
        _composeBarView = [[PHFComposeBarView alloc] initWithFrame:frame];
        [_composeBarView setMaxCharCount:160];
        [_composeBarView setMaxLinesCount:5];
        [_composeBarView setPlaceholder:@"Type something..."];
        [_composeBarView setUtilityButtonImage:[UIImage imageNamed:@"Camera"]];
        [_composeBarView setDelegate:self];
    }

    return _composeBarView;
}

@synthesize textView = _textView;
- (UITextView *)textView {
    if (!_textView) {
        CGRect frame = CGRectMake(0.0f,
                                  0.0f,
                                  kInitialViewFrame.size.width,
                                  kInitialViewFrame.size.height - [[self composeBarView] bounds].size.height);
        _textView = [[UITextView alloc] initWithFrame:frame];
        [_textView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
        [_textView setEditable:NO];
        [_textView setBackgroundColor:[UIColor clearColor]];
        [_textView setAlwaysBounceVertical:YES];
        [_textView setFont:[UIFont systemFontOfSize:[UIFont labelFontSize]]];
        [_textView setText:@"Welcome to the Demo!\n\nThis is just some placeholder text to give you a better feeling of how the compose bar can be used along other components."];
    }

    return _textView;
}

@end
