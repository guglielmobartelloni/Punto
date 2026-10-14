// Native integration test with an isolated, volatile preferences domain.
// App launches are intercepted; no real apps are opened and no settings are saved.
#define main PuntoEntryPoint
#import "../main.m"
#undef main
#include <assert.h>
@interface LauncherTestApp : App
@property NSString *launchedPath;
@property NSInteger launchCount;
@end
@implementation LauncherTestApp
- (void)launchApplication:(NSString *)path {self.launchedPath=path;self.launchCount++;}
- (void)saveNavigationMode {}
@end
static NSString *appPath(NSString *identifier){
    return [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier].path?:@"";
}
int main(void){@autoreleasepool{
    NSApplication *application=NSApplication.sharedApplication;
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSDictionary *original=[defaults volatileDomainForName:NSArgumentDomain];
    NSArray *up=@[appPath(@"com.apple.finder"),appPath(@"com.apple.Terminal")];
    NSArray *right=@[appPath(@"com.apple.Notes"),appPath(@"com.apple.Safari")];
    NSArray *down=@[appPath(@"com.apple.Music"),appPath(@"com.apple.systempreferences")];
    NSArray *left=@[appPath(@"com.apple.calculator"),appPath(@"com.apple.Maps")];
    assert([up[0] length]>0&&[up[1] length]>0);
    [defaults setVolatileDomain:@{@"launcherApps0":up,@"launcherApps1":right,@"launcherApps2":down,@"launcherApps3":left,@"action1":@11,@"app1":@"normal-cross-action",@"action2":@11,@"app2":@"normal-circle-action"} forName:NSArgumentDomain];
    LauncherTestApp *delegate=[LauncherTestApp new];application.delegate=delegate;currentApp=delegate;
    delegate.speed=1100;delegate.deadzone=0.12;input_button_handler(handle_button);input_enable(true);
    assert([delegate handleButton:5 pressed:YES]);assert(input_scroll_active());
    assert([delegate handleButton:15 pressed:YES]);assert(!input_scroll_active());
    assert([[delegate settingsSnapshot][@"launcherVisible"] boolValue]);
    assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==0);
    assert(!delegate.launchedPath&&[delegate.pendingLauncherPath isEqual:up[0]]);
    assert(delegate.launcherOpenedTime==0&&[[delegate settingsSnapshot][@"launcherLaunchTime"] doubleValue]>0);
    NSPanel *initialPanel=delegate.launcherPanel;
    NSView *initialHost=initialPanel.contentView;
    NSRect initialFrame=initialPanel.frame;
    double firstDeadline=delegate.launcherLaunchTime;
    [delegate updateLauncherAtTime:firstDeadline-0.01 trusted:YES];assert(delegate.launchCount==0);
    assert(application.activationPolicy==NSApplicationActivationPolicyAccessory);
    assert(!delegate.launcherPanel.isKeyWindow);
    assert(delegate.launcherPanel.isVisible); // Overlay alone must not add a Dock icon.
    assert(delegate.launcherPanel.contentView.bounds.size.width<=368);
    assert(delegate.launcherPanel.contentView.bounds.size.height<=368);
    assert([delegate handleButton:15 pressed:NO]);
    [delegate handleButton:15 pressed:YES];
    assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==1);
    assert(delegate.launcherPanel==initialPanel&&delegate.launcherPanel.contentView==initialHost);
    assert(delegate.launcherPanel.isVisible&&NSEqualRects(delegate.launcherPanel.frame,initialFrame));
    assert(!delegate.launchedPath&&[delegate.pendingLauncherPath isEqual:up[1]]);
    assert(delegate.launcherLaunchTime>firstDeadline);
    [delegate updateLauncherAtTime:firstDeadline trusted:YES];assert(delegate.launchCount==0);
    [delegate updateLauncherAtTime:delegate.launcherLaunchTime trusted:YES];
    assert([delegate.launchedPath isEqual:up[1]]&&delegate.launchCount==1);
    double openedTime=delegate.launcherOpenedTime;assert(openedTime>0&&delegate.launcherLaunchTime==0);
    [delegate updateLauncherAtTime:firstDeadline+1 trusted:YES];assert(delegate.launchCount==1&&delegate.launcherOpenedTime==openedTime);
    [delegate handleButton:18 pressed:YES];assert(delegate.launcherOpenedTime==0);
    assert([[delegate settingsSnapshot][@"launcherDirection"] intValue]==3);
    assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==0);
    assert([delegate handleButton:7 pressed:YES]); // R2 is consumed while navigating.
    [delegate handleButton:18 pressed:YES];assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==1);
    [delegate handleButton:16 pressed:YES];
    assert([[delegate settingsSnapshot][@"launcherDirection"] intValue]==3&&[[delegate settingsSnapshot][@"launcherSlot"] intValue]==0);
    assert([delegate.pendingLauncherPath isEqual:left[0]]&&delegate.launchCount==1);
    [delegate handleButton:16 pressed:YES];
    assert([[delegate settingsSnapshot][@"launcherDirection"] intValue]==1&&[delegate.pendingLauncherPath isEqual:right[0]]);
    NSString *beforeCancel=delegate.launchedPath;
    [delegate handleButton:2 pressed:YES];
    assert(![[delegate settingsSnapshot][@"launcherVisible"] boolValue]);
    assert(!delegate.launcherPanel.isVisible&&input_enabled());
    assert(delegate.launcherOpenedTime==0&&delegate.launcherLaunchTime==0);
    [delegate updateLauncherAtTime:firstDeadline+5 trusted:YES];
    assert([delegate.launchedPath isEqualToString:beforeCancel]&&delegate.launchCount==1); // Circle cancels the pending app.
    [delegate handleButton:15 pressed:YES];[delegate handleButton:15 pressed:YES];
    [delegate handleButton:1 pressed:YES];
    assert(delegate.launchCount==1); // X does not bypass the delay.
    [delegate updateLauncherAtTime:delegate.launcherLaunchTime trusted:YES];
    assert([delegate.launchedPath isEqualToString:up[1]]&&delegate.launchCount==2);
    assert([[delegate settingsSnapshot][@"launcherVisible"] boolValue]); // X is not a confirmation.
    assert(delegate.launcherHideTime>NSProcessInfo.processInfo.systemUptime);
    [delegate handleButton:15 pressed:YES];input_enable(false);
    assert(!delegate.launcherPanel.isVisible);
    [delegate updateLauncherAtTime:firstDeadline+5 trusted:YES];assert(delegate.launchCount==2);
    input_enable(true);[delegate handleButton:15 pressed:YES];
    [delegate updateLauncherAtTime:delegate.launcherLaunchTime trusted:NO];
    [delegate updateLauncherAtTime:firstDeadline+5 trusted:YES];assert(delegate.launchCount==2);
    [delegate handleButton:15 pressed:YES];[delegate setUINavigationEnabled:YES];
    [delegate updateLauncherAtTime:firstDeadline+5 trusted:YES];assert(delegate.launchCount==2);
    [delegate setUINavigationEnabled:NO];[delegate handleButton:15 pressed:YES];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    NSView *view=delegate.launcherPanel.contentView;[view layoutSubtreeIfNeeded];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    assert([bitmap colorAtX:bitmap.pixelsWide/2 y:bitmap.pixelsHigh/2].alphaComponent<0.01);
    assert([bitmap colorAtX:0 y:0].alphaComponent<0.01);
    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert([png writeToFile:@"build/ui-launcher.png" atomically:YES]);
    // Capture the real-time pulse using an intercepted launch, never a real app.
    delegate.launcherLaunchTime=NSProcessInfo.processInfo.systemUptime;
    [delegate updateLauncherAtTime:delegate.launcherLaunchTime trusted:YES];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.14]];
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *pulseBitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:pulseBitmap];
    NSData *pulsePNG=[pulseBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert([pulsePNG writeToFile:@"build/ui-launcher-pulse.png" atomically:YES]);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.32]];
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *settledBitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:settledBitmap];
    NSData *settledPNG=[settledBitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert(![pulsePNG isEqual:settledPNG]); // Pulse must advance without any selection change.
    assert([settledPNG writeToFile:@"build/ui-launcher-settled.png" atomically:YES]);
    NSMutableDictionary *sparse=[[defaults volatileDomainForName:NSArgumentDomain] mutableCopy];
    sparse[@"launcherApps0"]=@[@"",@""];
    [defaults setVolatileDomain:sparse forName:NSArgumentDomain];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *emptyBitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:emptyBitmap];
    assert([emptyBitmap colorAtX:emptyBitmap.pixelsWide/2 y:emptyBitmap.pixelsHigh*44/368].alphaComponent<0.01);
    assert([emptyBitmap colorAtX:emptyBitmap.pixelsWide/2 y:emptyBitmap.pixelsHigh*114/368].alphaComponent<0.01);
    [delegate hideLauncher];input_stop();input_button_handler(NULL);currentApp=nil;
    [defaults setVolatileDomain:original?:@{} forName:NSArgumentDomain];
    puts("PASS: delayed latest-selection launch, deadline reset, one-shot launch/pulse timestamps, cancellation feedback reset, cancel/pause/permission/mode-change safety, compact tiles-only layout, no focus or Dock activation");
}return 0;}
