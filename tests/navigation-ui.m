// Isolated routing test. No app launches, key injection, or preference writes.
#define main PuntoEntryPoint
#import "../main.m"
#undef main
#include <assert.h>
@interface NavigationSpy : PuntoUINavigation
@property NSInteger moves;
@property NSInteger direction;
@property NSInteger activations;
@property NSInteger backs;
@end
@implementation NavigationSpy
- (void)move:(NSInteger)direction {self.moves++;self.direction=direction;}
- (void)moveFromStick:(NSInteger)direction {[self move:direction];}
- (void)activateSelection {self.activations++;}
- (void)goBack {self.backs++;}
@end
@interface NavigationTestApp : App
@property NSString *launchedPath;
@end
@implementation NavigationTestApp
- (void)launchApplication:(NSString *)path {self.launchedPath=path;}
- (void)saveNavigationMode {} // Keep test mode changes out of persistent preferences.
@end
int main(void){@autoreleasepool{
    [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSDictionary *original=[defaults volatileDomainForName:NSArgumentDomain];
    [defaults setVolatileDomain:@{@"launcherApps0":@[@"demo-app",@""],@"action1":@11,@"app1":@"cross-app",@"action2":@11,@"app2":@"circle-app",@"action8":@11,@"app8":@"old-select-app",@"action13":@11,@"app13":@"touchpad-app"} forName:NSArgumentDomain];
    NavigationTestApp *app=[NavigationTestApp new];NavigationSpy *spy=[NavigationSpy new];app.uiNavigation=spy;currentApp=app;
    input_button_handler(handle_button);input_enable(true);
    [app setUINavigationEnabled:YES];
    for(int i=0;i<4;i++){[app handleButton:15+i pressed:YES];assert(spy.direction==i);[app handleButton:15+i pressed:NO];}
    assert(spy.moves==4&&!app.launcherPanel.isVisible&&!app.launchedPath);
    for(int i=0;i<4;i++){[app navigateStickDirection:i];assert(spy.direction==i);}
    assert(spy.moves==8&&!app.launchedPath);
    [app handleButton:1 pressed:YES];[app handleButton:1 pressed:NO];assert(spy.activations==1);
    [app handleButton:2 pressed:YES];[app handleButton:2 pressed:NO];assert(spy.backs==1&&!app.launchedPath);
    [app handleButton:5 pressed:YES];assert(input_scroll_active());[app handleButton:5 pressed:NO];
    [app handleButton:8 pressed:YES];assert(!app.navigationMode&&!input_scroll_active());
    [app handleButton:8 pressed:NO];assert(!app.navigationMode);
    [app handleButton:1 pressed:YES];assert([app.launchedPath isEqual:@"cross-app"]);
    [app navigateStickDirection:0];assert(app.launcherPanel.isVisible&&[app.launchedPath isEqual:@"demo-app"]);
    [app handleButton:8 pressed:YES];assert(app.navigationMode&&!app.launcherPanel.isVisible);
    assert([defaults integerForKey:@"action8"]==11&&[[defaults stringForKey:@"app8"] isEqual:@"old-select-app"]);
    assert(![app validButton:8]&&[app validButton:13]);
    [app handleButton:13 pressed:YES];assert([app.launchedPath isEqual:@"touchpad-app"]&&app.navigationMode);
    input_enable(false);assert(!spy.active);
    [app navigateStickDirection:0];assert(spy.moves==8);
    // Coalesce analog repeats without discarding digital presses or activation.
    PuntoUINavigation *queueTest=[PuntoUINavigation new];queueTest.active=YES;[queueTest setValue:@YES forKey:@"busy"];
    NSMutableArray<NSNumber *> *commands=[queueTest valueForKey:@"commands"];[commands addObjectsFromArray:@[@0,@4]];
    [queueTest moveFromStick:1];[queueTest moveFromStick:2];assert(commands.count==3&&commands.lastObject.intValue==12);
    [queueTest stopStickNavigation];assert(([commands isEqual:@[@0,@4]]));
    queueTest.active=NO;assert(commands.count==0);
    assert([[app settingsSnapshot][@"uiNavigation"] boolValue]);
    input_stop();input_button_handler(NULL);currentApp=nil;
    [defaults setVolatileDomain:original?:@{} forName:NSArgumentDomain];
    puts("PASS: D-pad/left-stick routing, repeat coalescing, activation/back, no shortcut leakage, Select/Create mode switching and customizable touchpad, launcher restoration, pause and preserved assignments");
}return 0;}
