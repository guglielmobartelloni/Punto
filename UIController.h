#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
@protocol PadMacUIController <NSObject>
- (NSDictionary *)settingsSnapshot;
- (void)setMouseSpeed:(double)speed deadzone:(double)deadzone;
- (void)setScrollSpeed:(double)speed;
- (void)toggleControl;
- (void)setUINavigationEnabled:(BOOL)enabled;
- (void)openAccessibility;
- (void)assignAction:(NSInteger)action forButton:(NSInteger)index;
- (void)recordHoldForButton:(NSInteger)index;
- (void)removeHoldForButton:(NSInteger)index;
- (void)configureLauncherDirection:(NSInteger)direction slot:(NSInteger)slot;
- (void)clearLauncherDirection:(NSInteger)direction slot:(NSInteger)slot;
- (void)selectLauncherDirection:(NSInteger)direction;
- (void)hideLauncher;
@end
NS_ASSUME_NONNULL_END
