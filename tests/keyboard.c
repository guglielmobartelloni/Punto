#define PADMAC_KEYBOARD_TEST
#include "../keyboard.c"
#include "../input.c"
#include <assert.h>
#include <stdio.h>
static struct {CGKeyCode key;bool down;CGEventFlags flags;bool modifier;} events[100];
static int count;
void keyboard_test_event(CGKeyCode key,bool down,CGEventFlags flags,bool modifier){
    assert(count<100);events[count].key=key;events[count].down=down;events[count].flags=flags;events[count].modifier=modifier;count++;
}
static void reset(void){keyboard_release_all();count=0;}
int main(void){
    CGEventFlags chord=kCGEventFlagMaskAlternate|kCGEventFlagMaskShift;
    keyboard_hold(0,-1,chord,true);
    assert(count==2 && events[0].key==58 && events[0].down);
    assert(events[1].key==56 && events[1].down && events[1].flags==chord);
    // A maintained press does not emit releases or repeat presses.
    keyboard_hold(0,-1,chord,true);assert(count==2);
    assert(current_flags()==chord);
    keyboard_hold(0,-1,0,false);
    assert(count==4 && !events[2].down && events[2].flags==kCGEventFlagMaskAlternate);
    assert(!events[3].down && events[3].flags==0 && current_flags()==0);
    reset();
    keyboard_hold(0,1,kCGEventFlagMaskCommand,true);
    assert(count==2 && events[1].key==1 && events[1].down);
    keyboard_hold(1,1,kCGEventFlagMaskCommand,true);assert(count==2);
    keyboard_hold(0,-1,0,false);assert(count==2 && current_flags()==kCGEventFlagMaskCommand);
    keyboard_hold(1,-1,0,false);assert(count==4 && events[2].key==1 && !events[2].down && events[3].flags==0);
    reset();
    keyboard_hold(0,-1,chord,true);
    keyboard_hold(1,8,kCGEventFlagMaskCommand|kCGEventFlagMaskShift,true);
    keyboard_release_all();assert(current_flags()==0);
    for(int i=0;i<128;i++)assert(keyReferences[i]==0);
    for(int i=0;i<19;i++)assert(!slots[i].active);
    int after=count;keyboard_release_all();assert(count==after);
    reset();
    keyboard_hold(-1,1,chord,true);keyboard_hold(19,1,chord,true);keyboard_hold(0,128,chord,true);
    keyboard_hold(0,-1,0,true);assert(count==0);
    keyboard_hold(0,-1,chord,true);input_suppress_pointer(true);assert(pointerSuppressed);
    input_enable(false);assert(current_flags()==0&&!pointerSuppressed);
    keyboard_hold(0,-1,chord,true);
    active=(IOHIDDeviceRef)(uintptr_t)1;removed(NULL,kIOReturnSuccess,NULL,active);
    assert(current_flags()==0 && !input_connected());
    keyboard_hold(0,-1,chord,true);input_stop();assert(current_flags()==0);
    puts("PASS: hold until release, Option+Shift, shared chords, suspend/disconnect/quit cleanup");
    return 0;
}
