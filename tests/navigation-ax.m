// Live AX test against this process's own harmless fixture window only.
#import "../UINavigation.h"
#include <assert.h>
@interface FixtureNavigation : PuntoUINavigation @end
@implementation FixtureNavigation
// Never inspect or act on another app, even if the user changes focus during the test.
- (pid_t)frontmostPID{return NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==getpid()?getpid():0;}
@end
@interface Fixture : NSObject
@property NSInteger clicks;
@property NSInteger backs;
- (void)click:(id)sender;
@end
@implementation Fixture
- (void)click:(id)sender {(void)sender;self.clicks++;fprintf(stderr,"Fixture clicks: %ld\n",(long)self.clicks);}
@end
static void waitForNavigation(PuntoUINavigation *nav){
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    do{[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];}while([[nav valueForKey:@"busy"] boolValue]&&deadline.timeIntervalSinceNow>0);
    fprintf(stderr,"Fixture status: %s\n",nav.status.UTF8String);
    assert(![[nav valueForKey:@"busy"] boolValue]);
}
int main(void){@autoreleasepool{
    NSApplication *application=NSApplication.sharedApplication;[application setActivationPolicy:NSApplicationActivationPolicyRegular];[application finishLaunching];
    NSArray *arguments=NSProcessInfo.processInfo.arguments;
    NSUInteger resultIndex=[arguments indexOfObject:@"--result"];
    NSString *resultPath=resultIndex!=NSNotFound&&resultIndex+1<arguments.count?arguments[resultIndex+1]:nil;
    if(resultPath)freopen([[resultPath stringByAppendingString:@".log"] fileSystemRepresentation],"w",stderr);
    if(!AXIsProcessTrusted()){
        fprintf(stderr,"SKIP: live AX test requires Accessibility permission for its signed fixture bundle.\n");
        if(resultPath)[@"SKIP: Accessibility permission required." writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return 77;
    }
    Fixture *fixture=[Fixture new];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(200,200,620,340) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.title=@"Punto Accessibility Test";
    for(NSDictionary *item in @[@{@"title":@"Left",@"x":@40,@"y":@220},@{@"title":@"Right",@"x":@220,@"y":@220},@{@"title":@"Down",@"x":@40,@"y":@140},@{@"title":@"Disabled",@"x":@400,@"y":@220}]){
        NSButton *button=[[NSButton alloc] initWithFrame:NSMakeRect([item[@"x"] doubleValue],[item[@"y"] doubleValue],130,36)];
        button.title=item[@"title"];button.bezelStyle=NSBezelStyleRounded;button.target=fixture;button.action=@selector(click:);button.enabled=![button.title isEqual:@"Disabled"];[window.contentView addSubview:button];
    }
    NSButton *hidden=[[NSButton alloc] initWithFrame:NSMakeRect(400,220,130,36)];hidden.title=@"Hidden";hidden.hidden=YES;hidden.target=fixture;hidden.action=@selector(click:);[window.contentView addSubview:hidden];
    NSButton *offscreen=[[NSButton alloc] initWithFrame:NSMakeRect(700,220,130,36)];offscreen.title=@"Offscreen";offscreen.target=fixture;offscreen.action=@selector(click:);[window.contentView addSubview:offscreen];
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(220,140,160,30)];[field setAccessibilityLabel:@"Editable field"];[window.contentView addSubview:field];
    [window makeKeyAndOrderFront:nil];[window makeFirstResponder:window];[application activateIgnoringOtherApps:YES];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.6]];
    assert(NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier==getpid());
    PuntoUINavigation *nav=[FixtureNavigation new];nav.backFallback=^{fixture.backs++;};nav.active=YES;
    [nav move:1];waitForNavigation(nav);assert([nav.status containsString:@"Left"]);
    NSPanel *highlight=[nav valueForKey:@"highlight"];assert(highlight.isVisible&&!highlight.isKeyWindow&&highlight.ignoresMouseEvents);
    [nav move:1];waitForNavigation(nav);assert([nav.status containsString:@"Right"]);
    [nav move:1];waitForNavigation(nav);assert([nav.status containsString:@"Right"]); // Disabled control is not selectable.
    [nav activateSelection];waitForNavigation(nav);assert(fixture.clicks==1&&highlight.isVisible&&!highlight.isKeyWindow);
    nav.active=NO;nav.active=YES;[window makeFirstResponder:window];[nav move:1];waitForNavigation(nav);
    [nav move:1];waitForNavigation(nav);[nav move:2];waitForNavigation(nav);assert([nav.status containsString:@"Editable field"]);
    [nav activateSelection];waitForNavigation(nav);assert(window.firstResponder==field.currentEditor);
    nav.active=NO;nav.active=YES;[window makeFirstResponder:window];[nav move:1];waitForNavigation(nav);
    [nav activateSelection];nav.active=NO;waitForNavigation(nav);assert(fixture.clicks==1&&!highlight.isVisible);
    nav.active=YES;[nav move:1];waitForNavigation(nav);
    NSWindow *sheet=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,260,140) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];sheet.title=@"Modal fixture";
    NSButton *sheetControl=[[NSButton alloc] initWithFrame:NSMakeRect(40,60,160,36)];sheetControl.title=@"Sheet control";sheetControl.target=fixture;sheetControl.action=@selector(click:);[sheet.contentView addSubview:sheetControl];
    [window beginSheet:sheet completionHandler:nil];[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
    [nav activateSelection];waitForNavigation(nav);assert(fixture.clicks==1);
    [nav move:1];waitForNavigation(nav);assert([nav.status containsString:@"Sheet control"]);
    [nav move:3];waitForNavigation(nav);assert([nav.status containsString:@"Sheet control"]);
    [nav activateSelection];waitForNavigation(nav);assert(fixture.clicks==2);
    [window endSheet:sheet];[sheet orderOut:nil];[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
    nav.active=NO;nav.active=YES;[window makeFirstResponder:window];[nav move:1];waitForNavigation(nav);
    NSWindow *other=[[NSWindow alloc] initWithContentRect:NSMakeRect(300,300,300,180) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];other.title=@"Empty fixture";[other makeKeyAndOrderFront:nil];
    [nav activateSelection];waitForNavigation(nav);assert(fixture.clicks==2&&!highlight.isVisible);
    [nav goBack];waitForNavigation(nav);assert(fixture.backs==1);
    nav.active=NO;[other orderOut:nil];[window orderOut:nil];
    if(resultPath)[@"PASS: real AX discovery, visibility filtering, activation, field focus, modal isolation and safety." writeToFile:resultPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    puts("PASS: real AX discovery, geometric movement, disabled exclusion, nonactivating highlight, AXPress, field focus, canceled pending action and stale-window rejection");
}return 0;}
