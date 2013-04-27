#import "PHFAppDelegate.h"
#import "PHFViewController.h"

@implementation PHFAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[self window] setRootViewController:[PHFViewController new]];
    [[self window] makeKeyAndVisible];

    return YES;
}

@synthesize window = _window;
- (UIWindow *)window {
    if (!_window)
        _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    return _window;
}

@end
