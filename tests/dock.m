// Optional native lifecycle smoke test: opens and closes only its own window.
#define main PadMacEntryPoint
#import "../main.m"
#undef main
#include <assert.h>
int main(void){@autoreleasepool{
    NSApplication *application=NSApplication.sharedApplication;
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
    App *delegate=[App new];application.delegate=delegate;
    delegate.speed=1100;delegate.deadzone=0.12;
    delegate.window=[PadMacUI makeWindowWithController:delegate];delegate.window.delegate=delegate;
    [delegate show:nil];
    assert(application.activationPolicy==NSApplicationActivationPolicyRegular);
    assert(delegate.window.isVisible);
    input_enable(true);
    assert([delegate handleButton:5 pressed:YES]);assert(input_scroll_active());
    assert([delegate handleButton:5 pressed:NO]);assert(!input_scroll_active());
    [delegate.window performClose:nil];
    assert(application.activationPolicy==NSApplicationActivationPolicyAccessory);
    assert(!delegate.window.isVisible);
    assert(input_enabled()); // Closing settings must not suspend controller input.
    BOOL reopened=[delegate applicationShouldHandleReopen:application hasVisibleWindows:NO];
    assert(reopened&&application.activationPolicy==NSApplicationActivationPolicyRegular);
    assert(delegate.window.isVisible);
    [delegate.window performClose:nil];input_stop();
    puts("PASS: Dock on settings open, hidden on close, reopen, controller state preserved");
}return 0;}
