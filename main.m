#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "input.h"
#import "ShortcutRecorder.h"
#import "keyboard.h"
#import "longpress.h"
#import "UIController.h"
#import "build/PadMacUI-Swift.h"

@interface App : NSObject <NSApplicationDelegate,NSWindowDelegate,PadMacUIController>
@property NSStatusItem *item;
@property NSWindow *window;
@property NSTimer *timer;
@property double lastTime;
@property double speed;
@property double deadzone;
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
- (BOOL)validButton:(NSInteger)index {return index>=0&&index<19&&index!=9;}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;currentApp=self;
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;PadMacMigrateShortcuts(d);
    [d registerDefaults:@{@"speed":@1100,@"zone":@0.12}];
    self.speed=MAX(200,MIN(2600,[d doubleForKey:@"speed"]));
    self.deadzone=MAX(0.03,MIN(0.4,[d doubleForKey:@"zone"]));
    self.item=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.image=[NSImage imageWithSystemSymbolName:@"gamecontroller.fill" accessibilityDescription:@"Punto"];
    NSMenu *menu=[NSMenu new];
    NSMenuItem *settings=[[NSMenuItem alloc] initWithTitle:@"Impostazioni Punto…" action:@selector(show:) keyEquivalent:@""];settings.target=self;[menu addItem:settings];
    NSMenuItem *toggle=[[NSMenuItem alloc] initWithTitle:@"Attiva / sospendi" action:@selector(toggle:) keyEquivalent:@""];toggle.target=self;[menu addItem:toggle];
    [menu addItem:[NSMenuItem separatorItem]];[menu addItemWithTitle:@"Esci" action:@selector(terminate:) keyEquivalent:@"q"];self.item.menu=menu;
    self.window=[PadMacUI makeWindowWithController:self];self.window.delegate=self;
    input_button_handler(handle_button);input_start();self.lastTime=NSProcessInfo.processInfo.systemUptime;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1.0/120 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];[self show:nil];
    [self savePreviewIfRequested];
}
- (NSDictionary *)settingsSnapshot {
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    NSArray *names=@[@"Quadrato",@"Croce",@"Cerchio",@"Triangolo",@"Dorsale L1",@"Dorsale R1",@"Grilletto L2",@"Grilletto R2",@"Create",@"Options",@"Joystick sinistro · L3",@"Joystick destro · R3",@"Pulsante PS",@"Click touchpad",@"Mute",@"Freccia su",@"Freccia destra",@"Freccia giù",@"Freccia sinistra"];
    NSArray *glyphs=@[@"□",@"✕",@"○",@"△",@"L1",@"R1",@"L2",@"R2",@"≡",@"…",@"L3",@"R3",@"PS",@"▭",@"◌",@"↑",@"→",@"↓",@"←"];
    NSMutableArray *rows=[NSMutableArray new];
    for(int i=0;i<19;i++){
        if(i==9)continue;
        NSInteger action=[d integerForKey:[self actionKey:i]];
        NSString *group=i<4?@"Simboli":i<8?@"Dorsali":i>=15?@"Frecce":@"Altri pulsanti";
        NSString *primary=@"Nessuna azione";
        NSDictionary *shortcut=[d dictionaryForKey:[self shortcutKey:i]],*hold=[d dictionaryForKey:[self holdKey:i]];
        NSString *path=[d stringForKey:[self pathKey:i]];
        if(action==0&&i==6)primary=@"Click destro";
        if(action==0&&i==7)primary=@"Click sinistro";
        if(action==12)primary=shortcut[@"label"]?:@"Registra shortcut";
        if(action==11)primary=path.length?[NSFileManager.defaultManager displayNameAtPath:path]:@"Scegli applicazione";
        NSMutableDictionary *row=[@{@"id":@(i),@"name":names[i],@"glyph":glyphs[i],@"group":group,@"action":@(action),@"primary":primary} mutableCopy];
        if(hold[@"label"])row[@"hold"]=hold[@"label"];
        if(action==11&&path.length)row[@"appPath"]=path;
        [rows addObject:row];
    }
    return @{@"connected":@(input_connected()),@"enabled":@(input_enabled()),@"trusted":@(AXIsProcessTrusted()),@"speed":@(self.speed),@"deadzone":@(self.deadzone),@"buttons":rows};
}
- (void)setMouseSpeed:(double)speed deadzone:(double)deadzone {
    self.speed=MAX(200,MIN(2600,speed));self.deadzone=MAX(0.03,MIN(0.4,deadzone));
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    [d setDouble:self.speed forKey:@"speed"];[d setDouble:self.deadzone forKey:@"zone"];
}
- (void)assignAction:(NSInteger)action forButton:(NSInteger)index {
    if(![self validButton:index] || (action!=0&&action!=10&&action!=11&&action!=12))return;
    input_enable(false);NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    if(action==12){
        NSDictionary *shortcut=PadMacRecordShortcut([d dictionaryForKey:[self shortcutKey:index]]);
        if(!shortcut)return;[d setObject:shortcut forKey:[self shortcutKey:index]];
    }
    if(action==11){
        NSOpenPanel *panel=[NSOpenPanel openPanel];panel.title=@"Scegli l’applicazione da richiamare";
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
- (BOOL)handleButton:(int)index pressed:(BOOL)pressed {
    if(index<0){longpress_cancel(hold_event);return YES;}
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
    if(action==11){
        NSString *path=[d stringForKey:[self pathKey:index]];if(!path.length)return YES;
        NSURL *url=[NSURL fileURLWithPath:path];NSWorkspaceOpenConfiguration *config=[NSWorkspaceOpenConfiguration configuration];config.activates=YES;
        [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){
            (void)app;if(error)dispatch_async(dispatch_get_main_queue(),^{
                input_enable(false);NSAlert *alert=[NSAlert new];alert.messageText=@"Impossibile aprire l’applicazione";
                alert.informativeText=@"L’app potrebbe essere stata spostata o rimossa. Selezionala nuovamente nelle impostazioni di Punto.";[alert runModal];
            });
        }];
    }
    return YES;
}
- (void)tick:(NSTimer *)timer {
    (void)timer;double now=NSProcessInfo.processInfo.systemUptime,dt=MIN(0.04,now-self.lastTime);self.lastTime=now;
    if(input_enabled()&&!AXIsProcessTrusted())input_enable(false);
    if(input_enabled())longpress_tick(now,hold_event);
    input_tick(dt,self.speed,self.deadzone);
}
- (void)toggleControl {
    if(input_enabled()){input_enable(false);return;}
    if(!AXIsProcessTrusted()){
        NSAlert *alert=[NSAlert new];alert.messageText=@"Permesso Accessibilità necessario";
        alert.informativeText=@"Abilita Punto in Impostazioni di Sistema → Privacy e sicurezza → Accessibilità.";[alert runModal];[self openAccessibility];return;
    }
    if(!input_connected()){
        NSAlert *alert=[NSAlert new];alert.messageText=@"DualSense non rilevato";
        alert.informativeText=@"Collega il controller con un cavo USB dati oppure abbinalo nelle impostazioni Bluetooth tenendo premuti PS + Create fino al lampeggio.";[alert runModal];return;
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
- (void)applicationWillTerminate:(NSNotification *)note {(void)note;[self.timer invalidate];input_stop();input_button_handler(NULL);currentApp=nil;}
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
