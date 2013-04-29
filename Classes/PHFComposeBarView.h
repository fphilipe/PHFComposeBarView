#import <UIKit/UIKit.h>

extern CGFloat const PHFComposeBarViewInitialHeight;

extern NSString * const PHFComposeBarViewWillChangeFrameNotification;
extern NSString * const PHFComposeBarViewFrameBeginUserInfoKey;        // NSValue of CGRect
extern NSString * const PHFComposeBarViewFrameEndUserInfoKey;          // NSValue of CGRect
extern NSString * const PHFComposeBarViewAnimationDurationUserInfoKey; // NSNumber of double
extern NSString * const PHFComposeBarViewAnimationCurveUserInfoKey;    // NSNumber of NSUInteger (UIViewAnimationCurve)

@protocol PHFComposeBarViewDelegate;

@interface PHFComposeBarView : UIView <UITextViewDelegate, NSCopying>

// The default value is 200.
@property (assign, nonatomic) CGFloat maxHeight;
// The default value is 9. This is just a conversion from the maxHeight property.
@property (assign, nonatomic) CGFloat maxLinesCount;
// The default value is nil. When not nil, a counter is shown.
@property (assign, nonatomic) NSUInteger maxCharCount;
// The default value is nil.
@property (strong, nonatomic) NSString *placeholder;
@property (strong, nonatomic) NSString *text;
// The default value is "Send".
@property (strong, nonatomic) NSString *buttonTitle;
// The default value is YES.
@property (assign, nonatomic, getter=isUtilityButtonHidden) BOOL utilityButtonHidden;
// The default value is nil. Images should be white on transparent background.
// The side length should not exceed 16px.
@property (strong, nonatomic) UIImage *utilityButtonImage;
@property (assign, nonatomic) id <PHFComposeBarViewDelegate> delegate;
@property (assign, nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) UILabel *placeholderLabel;

// When this is YES and the view height increases, it will also adjust its top
// offset such that the lower bound is fixed and the view grows upwards.  The
// default is YES.  Turning this off can be useful in some complicated view
// setups.
@property (assign, nonatomic) BOOL autoAdjustTopOffset;

@property (strong, nonatomic, readonly) UITextView *textView;

@end

// Note that only protocol methods defined directly in UITextViewDelegate are
// forwarded. Inheritet methods from UIScrollViewDelegate are ignored for now.
@protocol PHFComposeBarViewDelegate <NSObject, UITextViewDelegate>

@optional
- (void)textBarViewDidPressButton:(PHFComposeBarView *)textBarView;
- (void)textBarViewDidPressUtilityButton:(PHFComposeBarView *)textBarView;

@end
