// Native integration test with an isolated, volatile preferences domain.
// App launches are intercepted; no real apps are opened and no settings are saved.
#define main PuntoEntryPoint
#import "../main.m"
#undef main
#include <assert.h>
@interface LauncherTestApp : App
@property NSString *launchedPath;
@end
@implementation LauncherTestApp
- (void)launchApplication:(NSString *)path {self.launchedPath=path;}
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
    assert([delegate.launchedPath isEqualToString:up[0]]); // Immediate automatic launch.
    assert(application.activationPolicy==NSApplicationActivationPolicyAccessory);
    assert(!delegate.launcherPanel.isKeyWindow);
    assert(delegate.launcherPanel.isVisible); // Overlay alone must not add a Dock icon.
    assert(delegate.launcherPanel.contentView.bounds.size.width<=368);
    assert(delegate.launcherPanel.contentView.bounds.size.height<=368);
    assert([delegate handleButton:15 pressed:NO]);
    [delegate handleButton:15 pressed:YES];
    assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==1);
    assert([delegate.launchedPath isEqualToString:up[1]]);
    [delegate handleButton:18 pressed:YES];
    assert([[delegate settingsSnapshot][@"launcherDirection"] intValue]==3);
    assert([[delegate settingsSnapshot][@"launcherSlot"] intValue]==0);
    assert([delegate handleButton:7 pressed:YES]); // R2 is consumed while navigating.
    NSString *beforeCancel=delegate.launchedPath;
    [delegate handleButton:2 pressed:YES];
    assert(![[delegate settingsSnapshot][@"launcherVisible"] boolValue]);
    assert(!delegate.launcherPanel.isVisible&&input_enabled());
    assert([delegate.launchedPath isEqualToString:beforeCancel]); // Circle does not launch anything.
    [delegate handleButton:15 pressed:YES];[delegate handleButton:15 pressed:YES];
    [delegate handleButton:1 pressed:YES];
    assert([delegate.launchedPath isEqualToString:up[1]]);
    assert([[delegate settingsSnapshot][@"launcherVisible"] boolValue]); // X is not a confirmation.
    assert(delegate.launcherHideTime>NSProcessInfo.processInfo.systemUptime);
    [delegate handleButton:15 pressed:YES];input_enable(false);
    assert(!delegate.launcherPanel.isVisible);
    input_enable(true);[delegate handleButton:15 pressed:YES];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    NSView *view=delegate.launcherPanel.contentView;[view layoutSubtreeIfNeeded];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    assert([bitmap colorAtX:bitmap.pixelsWide/2 y:bitmap.pixelsHigh/2].alphaComponent<0.01);
    assert([bitmap colorAtX:0 y:0].alphaComponent<0.01);
    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert([png writeToFile:@"build/ui-launcher.png" atomically:YES]);
    [delegate hideLauncher];input_stop();input_button_handler(NULL);currentApp=nil;
    [defaults setVolatileDomain:original?:@{} forName:NSArgumentDomain];
    puts("PASS: automatic directional launch, two-slot cycle, cancel, suspend cleanup, compact tiles-only layout, no focus or Dock activation");
}return 0;}
