#import <Cocoa/Cocoa.h>
#include <math.h>
#import <ApplicationServices/ApplicationServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "input.h"
#import "ShortcutRecorder.h"
#import "keyboard.h"
#import "longpress.h"
#import "launcher.h"
#import "UINavigation.h"
#import "stick.h"
#import "UIController.h"
#import "build/PadMacUI-Swift.h"

@interface App : NSObject <NSApplicationDelegate,NSWindowDelegate,PadMacUIController> {
    LauncherState _launcher;
    StickNavigation _leftStick;
}
@property PuntoUINavigation *uiNavigation;
@property BOOL navigationMode;
@property NSPanel *launcherPanel;
@property double launcherHideTime;
@property double launcherLaunchTime;
@property NSString *pendingLauncherPath;
@property NSStatusItem *item;
@property NSWindow *window;
@property NSTimer *timer;
@property double lastTime;
@property double speed;
@property double deadzone;
@property(nonatomic) double scrollSpeed;
- (BOOL)handleButton:(int)index pressed:(BOOL)pressed;
- (void)holdEvent:(int)index event:(HoldEvent)event;
@end
static __weak App *currentApp;
static bool handle_button(int index,bool pressed){return [currentApp handleButton:index pressed:pressed];}
static void hold_event(int index,HoldEvent event){[currentApp holdEvent:index event:event];}

@implementation App
- (NSString *)actionKey:(NSInteger)index {return [NSString stringWithFormat:@"action%ld",(long)index];}
- (NSString *)pathKey:(NSInteger)index {return [NSString stringWithFormat:@"app%ld",(long)index];}
- (NSString *)shortcutKey:(NSInteger)index {return [NSString stringWithFormat:@"shortcut%ld",(long)index];}
- (NSString *)holdKey:(NSInteger)index {return [NSString stringWithFormat:@"holdShortcut%ld",(long)index];}
- (BOOL)validButton:(NSInteger)index {return index>=0&&index<19&&index!=9&&index!=5&&index!=8;}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;currentApp=self;
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;PadMacMigrateShortcuts(d);
    [d registerDefaults:@{@"speed":@1100,@"zone":@0.12,@"scrollSpeed":@900}];
    launcher_reset(&_launcher);stick_navigation_reset(&_leftStick);
    self.navigationMode=[d boolForKey:@"uiNavigation"];
    self.uiNavigation=[PuntoUINavigation new];
    __weak App *weakSelf=self;
    self.uiNavigation.backFallback=^{
        App *app=weakSelf;
        if(app.navigationMode&&input_enabled()&&AXIsProcessTrusted()){
            keyboard_hold(2,53,0,true);keyboard_hold(2,53,0,false);
        }
    };
    for(int direction=0;direction<4;direction++){
        NSString *key=[self launcherKey:direction];int button=15+direction;
        if(![d objectForKey:key]&&[d integerForKey:[self actionKey:button]]==11){
            NSString *path=[d stringForKey:[self pathKey:button]];
            if(path.length)[d setObject:@[path,@""] forKey:key];
        }
    }
    self.speed=MAX(200,MIN(2600,[d doubleForKey:@"speed"]));
    self.deadzone=MAX(0.03,MIN(0.4,[d doubleForKey:@"zone"]));
    self.scrollSpeed=MAX(100,MIN(3000,[d doubleForKey:@"scrollSpeed"]));
    self.item=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.image=[NSImage imageWithSystemSymbolName:@"gamecontroller.fill" accessibilityDescription:@"Punto"];
    NSMenu *menu=[NSMenu new];
    NSMenuItem *settings=[[NSMenuItem alloc] initWithTitle:@"Punto Settings…" action:@selector(show:) keyEquivalent:@""];settings.target=self;[menu addItem:settings];
    NSMenuItem *toggle=[[NSMenuItem alloc] initWithTitle:@"Enable / Pause" action:@selector(toggle:) keyEquivalent:@""];toggle.target=self;[menu addItem:toggle];
    [menu addItem:[NSMenuItem separatorItem]];[menu addItemWithTitle:@"Quit Punto" action:@selector(terminate:) keyEquivalent:@"q"];self.item.menu=menu;
    self.window=[PadMacUI makeWindowWithController:self];self.window.delegate=self;
    input_button_handler(handle_button);input_start();self.lastTime=NSProcessInfo.processInfo.systemUptime;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1.0/120 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];[self show:nil];
    [self savePreviewIfRequested];
}
- (NSDictionary *)settingsSnapshot {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    NSArray *names=@[@"Square",@"Cross",@"Circle",@"Triangle",@"Left bumper · L1",@"Right bumper · R1",@"Left trigger · L2",@"Right trigger · R2",@"Select / Create",@"Options",@"Left stick · L3",@"Right stick · R3",@"PS button",@"Touchpad click",@"Mute",@"D-pad up",@"D-pad right",@"D-pad down",@"D-pad left"];
    NSArray *glyphs=@[@"□",@"✕",@"○",@"△",@"L1",@"R1",@"L2",@"R2",@"≡",@"…",@"L3",@"R3",@"PS",@"▭",@"◌",@"↑",@"→",@"↓",@"←"];
    NSMutableArray *rows=[NSMutableArray new];
    for(int i=0;i<19;i++){
        if(i==9)continue;
        NSInteger action=[d integerForKey:[self actionKey:i]];
        NSString *group=i<4?@"Symbols":i<8?@"Shoulders":i>=15?@"D-pad":@"Other buttons";
        NSString *primary=@"No action";
        NSDictionary *shortcut=[d dictionaryForKey:[self shortcutKey:i]],*hold=[d dictionaryForKey:[self holdKey:i]];
        NSString *path=[d stringForKey:[self pathKey:i]];
        if(action==0&&i==6)primary=@"Right click";
        if(action==0&&i==7)primary=@"Left click";
        if(action==12)primary=PadMacShortcutLabel(shortcut)?:@"Record shortcut";
        if(action==11)primary=path.length?[NSFileManager.defaultManager displayNameAtPath:path]:@"Choose application";
        if(i==5){action=13;primary=@"Right stick → scroll";}
        if(i==8){action=14;primary=@"Toggle UI navigation";}
        if(self.navigationMode&&i==1){action=15;primary=@"Activate selection";}
        if(self.navigationMode&&i==2){action=16;primary=@"Back / Escape";}
        NSMutableDictionary *row=[@{@"id":@(i),@"name":names[i],@"glyph":glyphs[i],@"group":group,@"action":@(action),@"primary":primary} mutableCopy];
        if(i!=5&&i!=8&&!(self.navigationMode&&(i==1||i==2))&&hold[@"label"])row[@"hold"]=PadMacShortcutLabel(hold);
        if(action==11&&path.length)row[@"appPath"]=path;
        [rows addObject:row];
    }
    NSMutableArray *directions=[NSMutableArray new];
    for(int i=0;i<4;i++)[directions addObject:[self launcherApps:i]];
    return @{@"connected":@(input_connected()),@"enabled":@(input_enabled()),@"trusted":@(AXIsProcessTrusted()),@"speed":@(self.speed),@"deadzone":@(self.deadzone),@"scrollSpeed":@(self.scrollSpeed),@"buttons":rows,
             @"uiNavigation":@(self.navigationMode),@"navigationStatus":self.uiNavigation.status?:@"Press a direction to select a control.",
             @"launcherApps":directions,@"launcherVisible":@(_launcher.visible),@"launcherDirection":@(_launcher.direction),@"launcherSlot":@(_launcher.slot)};
}
- (void)setMouseSpeed:(double)speed deadzone:(double)deadzone {
    self.speed=MAX(200,MIN(2600,speed));self.deadzone=MAX(0.03,MIN(0.4,deadzone));
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    [d setDouble:self.speed forKey:@"speed"];[d setDouble:self.deadzone forKey:@"zone"];
}
- (void)setScrollSpeed:(double)speed {
    if(!isfinite(speed))return;
    _scrollSpeed=MAX(100,MIN(3000,speed));input_set_scroll_speed(_scrollSpeed);
    [NSUserDefaults.standardUserDefaults setDouble:_scrollSpeed forKey:@"scrollSpeed"];
}
- (void)assignAction:(NSInteger)action forButton:(NSInteger)index {
    if(![self validButton:index] || (action!=0&&action!=10&&action!=11&&action!=12))return;
    input_enable(false);NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    if(action==12){
        NSDictionary *shortcut=PadMacRecordShortcut([d dictionaryForKey:[self shortcutKey:index]]);
        if(!shortcut)return;[d setObject:shortcut forKey:[self shortcutKey:index]];
    }
    if(action==11){
        NSOpenPanel *panel=[NSOpenPanel openPanel];panel.title=@"Choose an application";panel.prompt=@"Choose";
        panel.canChooseFiles=YES;panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;
        panel.allowedContentTypes=@[UTTypeApplicationBundle];panel.treatsFilePackagesAsDirectories=NO;panel.directoryURL=[NSURL fileURLWithPath:@"/Applications"];
        if([panel runModal]!=NSModalResponseOK)return;
        NSURL *url=panel.URL;if(![url.pathExtension.lowercaseString isEqualToString:@"app"])return;
        [d setObject:url.path forKey:[self pathKey:index]];
    }
    [d setInteger:action forKey:[self actionKey:index]];
}
- (void)recordHoldForButton:(NSInteger)index {
    if(![self validButton:index])return;
    input_enable(false);NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    NSDictionary *shortcut=PadMacRecordShortcut([d dictionaryForKey:[self holdKey:index]]);
    if(shortcut)[d setObject:shortcut forKey:[self holdKey:index]];
}
- (void)removeHoldForButton:(NSInteger)index {
    if(![self validButton:index])return;input_enable(false);
    [NSUserDefaults.standardUserDefaults removeObjectForKey:[self holdKey:index]];
}
- (void)navigateStickDirection:(NSInteger)direction {
    if(direction<0||direction>3||!input_enabled())return;
    if(self.navigationMode)[self.uiNavigation moveFromStick:direction];
    else [self selectLauncherDirection:direction];
}
- (void)saveNavigationMode {[NSUserDefaults.standardUserDefaults setBool:self.navigationMode forKey:@"uiNavigation"];}
- (void)setUINavigationEnabled:(BOOL)enabled {
    input_release_actions();[self hideLauncher];
    self.navigationMode=enabled;[self saveNavigationMode];
    self.uiNavigation.active=enabled&&input_enabled()&&AXIsProcessTrusted();
}
- (BOOL)handleButton:(int)index pressed:(BOOL)pressed {
    if(index<0){longpress_cancel(hold_event);[self hideLauncher];self.uiNavigation.active=NO;stick_navigation_reset(&_leftStick);return YES;}
    if(index==8){if(pressed)[self setUINavigationEnabled:!self.navigationMode];return YES;}
    if(self.navigationMode&&(index>=15||index==1||index==2)){
        self.uiNavigation.active=input_enabled()&&AXIsProcessTrusted();
        if(pressed){
            if(index>=15&&index<=18)[self.uiNavigation move:index-15];
            else if(index==1)[self.uiNavigation activateSelection];
            else if(index==2)[self.uiNavigation goBack];
        }
        return YES;
    }
    if(index>=15&&index<=18){if(pressed)[self selectLauncherDirection:index-15];return YES;}
    if(_launcher.visible){
        if(pressed&&index==2)[self hideLauncher];
        return YES;
    }
    if(index==5){input_scroll_mode(pressed);return YES;}
    if([NSUserDefaults.standardUserDefaults dictionaryForKey:[self holdKey:index]]){
        longpress_button(index,pressed,NSProcessInfo.processInfo.systemUptime,hold_event);return YES;
    }
    return [self primaryButton:index pressed:pressed];
}
- (void)holdEvent:(int)index event:(HoldEvent)event {
    if(event==HOLD_ALTERNATE_DOWN){
        NSDictionary *shortcut=[NSUserDefaults.standardUserDefaults dictionaryForKey:[self holdKey:index]];
        NSNumber *key=shortcut[@"keycode"],*flags=shortcut[@"modifiers"];
        if(key&&flags)keyboard_hold(index,key.intValue,flags.unsignedLongLongValue,true);
    }else if(event==HOLD_ALTERNATE_UP)keyboard_hold(index,-1,0,false);
    else{
        BOOL down=event==HOLD_PRIMARY_DOWN;
        if(![self primaryButton:index pressed:down])input_default_button(index,down);
    }
}
- (BOOL)primaryButton:(int)index pressed:(BOOL)pressed {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;NSInteger action=[d integerForKey:[self actionKey:index]];
    if(action==0)return index<4?YES:NO;
    if(action==12){
        if(!pressed){keyboard_hold(index,-1,0,false);return YES;}
        NSDictionary *shortcut=[d dictionaryForKey:[self shortcutKey:index]];
        NSNumber *key=shortcut[@"keycode"],*modifiers=shortcut[@"modifiers"];
        if(key&&modifiers)keyboard_hold(index,key.intValue,modifiers.unsignedLongLongValue,true);
        return YES;
    }
    if(!pressed)return YES;
    if(action==11)[self launchApplication:[d stringForKey:[self pathKey:index]]];
    return YES;
}
- (NSString *)launcherKey:(NSInteger)direction {return [NSString stringWithFormat:@"launcherApps%ld",(long)direction];}
- (NSArray<NSString *> *)launcherApps:(NSInteger)direction {
    NSArray *stored=[NSUserDefaults.standardUserDefaults arrayForKey:[self launcherKey:direction]];
    NSMutableArray *apps=[@[@"",@""] mutableCopy];
    for(NSUInteger i=0;i<MIN((NSUInteger)2,stored.count);i++)if([stored[i] isKindOfClass:NSString.class])apps[i]=stored[i];
    return apps;
}
- (void)configureLauncherDirection:(NSInteger)direction slot:(NSInteger)slot {
    if(direction<0||direction>3||slot<0||slot>1)return;
    input_enable(false);
    NSOpenPanel *panel=[NSOpenPanel openPanel];panel.title=@"Choose an app for the Launcher";panel.prompt=@"Choose";
    panel.canChooseFiles=YES;panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;
    panel.allowedContentTypes=@[UTTypeApplicationBundle];panel.treatsFilePackagesAsDirectories=NO;panel.directoryURL=[NSURL fileURLWithPath:@"/Applications"];
    if([panel runModal]!=NSModalResponseOK||![panel.URL.pathExtension.lowercaseString isEqualToString:@"app"])return;
    NSMutableArray *apps=[[self launcherApps:direction] mutableCopy];apps[slot]=panel.URL.path;
    [NSUserDefaults.standardUserDefaults setObject:apps forKey:[self launcherKey:direction]];
}
- (void)clearLauncherDirection:(NSInteger)direction slot:(NSInteger)slot {
    if(direction<0||direction>3||slot<0||slot>1)return;input_enable(false);
    NSMutableArray *apps=[[self launcherApps:direction] mutableCopy];apps[slot]=@"";
    [NSUserDefaults.standardUserDefaults setObject:apps forKey:[self launcherKey:direction]];
}
- (void)selectLauncherDirection:(NSInteger)direction {
    if(direction<0||direction>3||!input_enabled())return;
    if(!_launcher.visible)input_release_actions();
    bool available[4][2];
    for(int i=0;i<4;i++){NSArray *apps=[self launcherApps:i];for(int j=0;j<2;j++)available[i][j]=[apps[j] length]>0;}
    launcher_select(&_launcher,(int)direction,available);
    input_suppress_pointer(true);
    if(!self.launcherPanel)self.launcherPanel=[PadMacUI makeLauncherWithController:self];
    [self.launcherPanel center];[self.launcherPanel orderFrontRegardless];
    double now=NSProcessInfo.processInfo.systemUptime;
    self.launcherHideTime=now+1.2;
    self.pendingLauncherPath=[self launcherApps:_launcher.direction][_launcher.slot];
    self.launcherLaunchTime=self.pendingLauncherPath.length?now+0.5:0;
}
- (void)hideLauncher {
    self.launcherHideTime=0;self.launcherLaunchTime=0;self.pendingLauncherPath=nil;launcher_reset(&_launcher);[self.launcherPanel orderOut:nil];
    self.launcherPanel.contentView=nil;self.launcherPanel=nil;input_suppress_pointer(false);
}
- (void)updateLauncherAtTime:(double)now trusted:(BOOL)trusted {
    if(!trusted||!input_enabled()||self.navigationMode){self.launcherLaunchTime=0;self.pendingLauncherPath=nil;return;}
    if(!_launcher.visible||self.launcherLaunchTime<=0||now<self.launcherLaunchTime)return;
    NSString *path=self.pendingLauncherPath;
    self.launcherLaunchTime=0;self.pendingLauncherPath=nil;
    if(path.length)[self launchApplication:path];
}
- (void)launchApplication:(NSString *)path {
    if(!path.length)return;
    NSWorkspaceOpenConfiguration *config=[NSWorkspaceOpenConfiguration configuration];config.activates=YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:path] configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){
        (void)app;if(error)dispatch_async(dispatch_get_main_queue(),^{
            input_enable(false);NSAlert *alert=[NSAlert new];alert.messageText=@"Unable to open application";
            alert.informativeText=@"The app may have been moved or removed. Select it again in Punto settings.";[alert runModal];
        });
    }];
}
- (void)tick:(NSTimer *)timer {
    (void)timer;double now=NSProcessInfo.processInfo.systemUptime,dt=MIN(0.04,now-self.lastTime);self.lastTime=now;
    if(_launcher.visible&&self.launcherHideTime>0&&now>=self.launcherHideTime)[self hideLauncher];
    BOOL trusted=!input_enabled()||AXIsProcessTrusted();
    if(input_enabled()&&!trusted)input_enable(false);
    if(input_enabled()&&!_launcher.visible)longpress_tick(now,hold_event);
    input_tick(dt,self.speed,self.deadzone);
    self.uiNavigation.active=self.navigationMode&&input_enabled()&&trusted;
    [self.uiNavigation poll];
    if(input_enabled()){
        double horizontal=0,vertical=0;input_left_stick(&horizontal,&vertical);
        int previous=_leftStick.direction;
        int direction=stick_navigation_step(&_leftStick,horizontal,vertical,now,self.navigationMode);
        if(previous>=0&&_leftStick.direction<0)[self.uiNavigation stopStickNavigation];
        if(direction>=0)[self navigateStickDirection:direction];
    }else stick_navigation_reset(&_leftStick);
    [self updateLauncherAtTime:now trusted:trusted];
}
- (void)toggleControl {
    if(input_enabled()){input_enable(false);return;}
    if(!AXIsProcessTrusted()){
        NSAlert *alert=[NSAlert new];alert.messageText=@"Accessibility permission required";
        alert.informativeText=@"Enable Punto in System Settings → Privacy & Security → Accessibility.";[alert runModal];[self openAccessibility];return;
    }
    if(!input_connected()){
        NSAlert *alert=[NSAlert new];alert.messageText=@"DualSense not detected";
        alert.informativeText=@"Connect the controller with a USB data cable, or pair it in Bluetooth settings by holding PS + Create until the light flashes.";[alert runModal];return;
    }
    input_enable(true);
}
- (void)openAccessibility {
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt:@YES});
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}
- (void)toggle:(id)sender {(void)sender;[self toggleControl];}
- (void)show:(id)sender {
    (void)sender;
    [self hideLauncher];self.uiNavigation.active=NO;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    if(self.window.isMiniaturized)[self.window deminiaturize:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)windowWillClose:(NSNotification *)notification {
    if(notification.object==self.window)[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {
    (void)application;(void)visible;[self show:nil];return YES;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    (void)application;return NO;
}
- (void)applicationWillTerminate:(NSNotification *)note {(void)note;[self.timer invalidate];self.uiNavigation.active=NO;input_stop();input_button_handler(NULL);currentApp=nil;}
// Optional local visual QA: captures only our own window content, not the desktop.
- (void)savePreviewIfRequested {
    NSArray<NSString *> *arguments=NSProcessInfo.processInfo.arguments;
    NSUInteger index=[arguments indexOfObject:@"--ui-preview"];
    if(index==NSNotFound||index+1>=arguments.count)return;
    NSString *path=arguments[index+1];
    if([arguments containsObject:@"--ui-dark"])self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    else self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        NSView *view=self.window.contentView;[view layoutSubtreeIfNeeded];
        NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
        NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if(![data writeToFile:path atomically:YES])NSLog(@"UI preview could not be saved");
    });
}
@end
int main(void){@autoreleasepool{NSApplication *app=NSApplication.sharedApplication;[app setActivationPolicy:NSApplicationActivationPolicyAccessory];App *delegate=[App new];app.delegate=delegate;[app run];}return 0;}
