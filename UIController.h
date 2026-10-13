#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
@protocol PadMacUIController <NSObject>
- (NSDictionary *)settingsSnapshot;
- (void)setMouseSpeed:(double)speed deadzone:(double)deadzone;
- (void)toggleControl;
- (void)openAccessibility;
- (void)assignAction:(NSInteger)action forButton:(NSInteger)index;
- (void)recordHoldForButton:(NSInteger)index;
- (void)removeHoldForButton:(NSInteger)index;
@end
NS_ASSUME_NONNULL_END
