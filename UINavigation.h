#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
NS_ASSUME_NONNULL_BEGIN
@interface PuntoUINavigation : NSObject
@property(nonatomic,readonly) NSString *status;
@property(atomic,getter=isActive) BOOL active;
@property(nonatomic,copy,nullable) dispatch_block_t backFallback;
- (void)move:(NSInteger)direction;
- (void)moveFromStick:(NSInteger)direction;
- (void)stopStickNavigation;
- (void)activateSelection;
- (void)goBack;
- (void)poll;
@end
NS_ASSUME_NONNULL_END
