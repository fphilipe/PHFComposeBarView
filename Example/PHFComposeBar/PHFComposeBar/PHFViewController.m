#import "PHFViewController.h"

@implementation PHFViewController

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
    [view setBackgroundColor:[UIColor colorWithHue:220/360.0 saturation:0.08 brightness:0.93 alpha:1]];

    [self setView:view];
}

@end
