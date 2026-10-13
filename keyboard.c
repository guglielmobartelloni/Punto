#include "keyboard.h"
#include <ApplicationServices/ApplicationServices.h>

// Reference counts keep shared keys/modifiers held across simultaneous buttons.
static unsigned int keyReferences[128];
static unsigned int modifierReferences[5];
static const CGKeyCode modifierKeys[]={59,58,56,55,63};
static const CGEventFlags modifierMasks[]={kCGEventFlagMaskControl,kCGEventFlagMaskAlternate,kCGEventFlagMaskShift,kCGEventFlagMaskCommand,kCGEventFlagMaskSecondaryFn};
static struct {bool active;int key;CGEventFlags modifiers;} slots[19];
static CGEventFlags current_flags(void){
    CGEventFlags flags=0;
    for(int i=0;i<5;i++)if(modifierReferences[i])flags|=modifierMasks[i];
    return flags;
}
static void post_key(CGKeyCode key,bool pressed,bool modifier){
#ifdef PADMAC_KEYBOARD_TEST
    extern void keyboard_test_event(CGKeyCode,bool,CGEventFlags,bool);
    keyboard_test_event(key,pressed,current_flags(),modifier);
#else
    CGEventRef event=CGEventCreateKeyboardEvent(NULL,key,pressed);
    if(!event)return;
    if(modifier)CGEventSetType(event,kCGEventFlagsChanged);
    CGEventSetFlags(event,current_flags());
    CGEventPost(kCGHIDEventTap,event);CFRelease(event);
#endif
}
void keyboard_hold(int slot,int keycode,unsigned long long modifiers,bool pressed){
    if(slot<0||slot>=19)return;
    if(pressed){
        if(slots[slot].active||keycode < -1||keycode>127)return;
        // Only supported modifier bits can become synthetic held state.
        CGEventFlags supported=0;for(int i=0;i<5;i++)supported|=modifierMasks[i];
        modifiers&=supported;
        if(keycode==-1&&!modifiers)return;
        slots[slot].active=true;slots[slot].key=keycode;slots[slot].modifiers=modifiers;
        for(int i=0;i<5;i++)if(modifiers&modifierMasks[i])
            if(modifierReferences[i]++==0)post_key(modifierKeys[i],true,true);
        if(keycode>=0 && keyReferences[keycode]++==0)post_key((CGKeyCode)keycode,true,false);
    }else{
        if(!slots[slot].active)return;
        // Release the original chord, even if preferences changed in the meantime.
        int key=slots[slot].key;CGEventFlags flags=slots[slot].modifiers;
        slots[slot].active=false;
        if(key>=0 && --keyReferences[key]==0)post_key((CGKeyCode)key,false,false);
        for(int i=4;i>=0;i--)if(flags&modifierMasks[i])
            if(--modifierReferences[i]==0)post_key(modifierKeys[i],false,true);
    }
}
void keyboard_release_all(void){
    for(int slot=0;slot<19;slot++)keyboard_hold(slot,-1,0,false);
}
