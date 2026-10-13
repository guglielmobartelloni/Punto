#include "input.h"
#include "keyboard.h"
#include <ApplicationServices/ApplicationServices.h>
#include <IOKit/hid/IOHIDManager.h>
#include <math.h>

static IOHIDManagerRef manager;
static IOHIDDeviceRef active;
static double x, y;
static uint8_t reportBuffer[512];
static bool touching;
static int touchX, touchY, touchID;
static void move_pointer(double dx, double dy);
static bool pointerSuppressed;
void input_suppress_pointer(bool suppressed){pointerSuppressed=suppressed;touching=false;}
static bool enabled, held[2]; // Left mouse (R2), right mouse (L2).
static bool buttons[19];
static InputButtonHandler buttonHandler;
void input_button_handler(InputButtonHandler handler){buttonHandler=handler;}
static int keys[4] = {8,9,36,49};
static unsigned long long flags[4] = {kCGEventFlagMaskCommand,kCGEventFlagMaskCommand,0,0};
static CGPoint position(void) {
    CGEventRef e=CGEventCreate(NULL);
    CGPoint p=CGEventGetLocation(e); CFRelease(e); return p;
}
static void mouse(CGEventType type, CGMouseButton button) {
    CGEventRef e=CGEventCreateMouseEvent(NULL,type,position(),button);
    if(e){CGEventPost(kCGHIDEventTap,e);CFRelease(e);}
}
void input_release_actions(void) {
    keyboard_release_all();
    if(buttonHandler)buttonHandler(-1,false);
    if(held[0]) mouse(kCGEventLeftMouseUp,kCGMouseButtonLeft);
    if(held[1]) mouse(kCGEventRightMouseUp,kCGMouseButtonRight);
    held[0]=held[1]=false;touching=false;
}
void input_enable(bool on) {
    input_release_actions();pointerSuppressed=false;enabled=on;x=y=0;
}
void input_mapping(int i,int key,unsigned long long mods) {if(i>=0&&i<4){keys[i]=key;flags[i]=mods;}}
void input_modifier_shortcut(unsigned long long modifiers){
    const CGKeyCode keys[]={59,58,56,55,63};
    const CGEventFlags masks[]={kCGEventFlagMaskControl,kCGEventFlagMaskAlternate,kCGEventFlagMaskShift,kCGEventFlagMaskCommand,kCGEventFlagMaskSecondaryFn};
    CGEventFlags current=0;
    for(int i=0;i<5;i++)if(modifiers&masks[i]){
        current|=masks[i];
        CGEventRef e=CGEventCreateKeyboardEvent(NULL,keys[i],true);
        if(e){CGEventSetType(e,kCGEventFlagsChanged);CGEventSetFlags(e,current);CGEventPost(kCGHIDEventTap,e);CFRelease(e);}
    }
    for(int i=4;i>=0;i--)if(modifiers&masks[i]){
        current&=~masks[i];
        CGEventRef e=CGEventCreateKeyboardEvent(NULL,keys[i],false);
        if(e){CGEventSetType(e,kCGEventFlagsChanged);CGEventSetFlags(e,current);CGEventPost(kCGHIDEventTap,e);CFRelease(e);}
    }
}
void input_shortcut(int i,int key,unsigned long long mods) {
    (void)i;
    CGEventRef down=CGEventCreateKeyboardEvent(NULL,(CGKeyCode)key,true);
    CGEventRef up=CGEventCreateKeyboardEvent(NULL,(CGKeyCode)key,false);
    if(down&&up){CGEventSetFlags(down,mods);CGEventSetFlags(up,mods);CGEventPost(kCGHIDEventTap,down);CGEventPost(kCGHIDEventTap,up);}
    if(down)CFRelease(down);if(up)CFRelease(up);
}
static void button(int index,bool pressed){
    if(index<0 || index>=19 || buttons[index]==pressed)return;
    buttons[index]=pressed;
    if(index==9){if(pressed)input_enable(!enabled);return;}
    if(!enabled)return;
    if(buttonHandler && buttonHandler(index,pressed))return;
    input_default_button(index,pressed);
}
void input_default_button(int index,bool pressed){
    if(index>=0 && index<4 && pressed)input_shortcut(index,keys[index],flags[index]);
    if(index==6 || index==7){
        int mouseIndex=index==7?0:1;
        if(held[mouseIndex]!=pressed){
            held[mouseIndex]=pressed;
            mouse(mouseIndex==0?(pressed?kCGEventLeftMouseDown:kCGEventLeftMouseUp)
                              :(pressed?kCGEventRightMouseDown:kCGEventRightMouseUp),
                  mouseIndex==0?kCGMouseButtonLeft:kCGMouseButtonRight);
        }
    }
}
static void value(void *ctx,IOReturn result,void *sender,IOHIDValueRef v) {
    (void)ctx;(void)sender;if(result!=kIOReturnSuccess)return;
    IOHIDElementRef e=IOHIDValueGetElement(v);
    if(IOHIDElementGetDevice(e)!=active)return;
    uint32_t page=IOHIDElementGetUsagePage(e),usage=IOHIDElementGetUsage(e);
    CFIndex n=IOHIDValueGetIntegerValue(v);
    if(page==kHIDPage_Button && usage>=1 && usage<=15)button((int)usage-1,n!=0);
    if(page==kHIDPage_GenericDesktop && usage==kHIDUsage_GD_Hatswitch){
        CFIndex direction=n-IOHIDElementGetLogicalMin(e);
        button(15,direction==0||direction==1||direction==7); // Up
        button(16,direction==1||direction==2||direction==3); // Right
        button(17,direction==3||direction==4||direction==5); // Down
        button(18,direction==5||direction==6||direction==7); // Left
    }
    if(page==kHIDPage_GenericDesktop && (usage==kHIDUsage_GD_Z||usage==kHIDUsage_GD_Rz)){
        double min=IOHIDElementGetLogicalMin(e),max=IOHIDElementGetLogicalMax(e);
        if(max<=min)return;
        double a=2.0*(n-min)/(max-min)-1;
        if(usage==kHIDUsage_GD_Z)x=a;else y=a;
    }
}
// DualSense USB (0x01) and full Bluetooth (0x31) input reports.
// The first touch contact follows 32 bytes of common input data.
static void report(void *ctx, IOReturn result, void *sender,
                   IOHIDReportType type, uint32_t reportID,
                   uint8_t *bytes, CFIndex length) {
    (void)sender;(void)reportID;
    if(result!=kIOReturnSuccess || ctx!=active || type!=kIOHIDReportTypeInput || length<1)return;
    int offset=bytes[0]==0x01?33:bytes[0]==0x31?35:-1;
    if(offset<0 || length<offset+4)return;
    if(!enabled || (bytes[offset]&0x80)){touching=false;return;}
    int id=bytes[offset]&0x7f;
    int tx=bytes[offset+1]|((bytes[offset+2]&0x0f)<<8);
    int ty=(bytes[offset+2]>>4)|(bytes[offset+3]<<4);
    if(tx>=1920 || ty>=1080){touching=false;return;}
    if(touching && id==touchID){
        // Relative tracking: a full-width swipe covers roughly 1500 points.
        move_pointer((tx-touchX)*0.8,(ty-touchY)*0.8);
    }
    touchX=tx;touchY=ty;touchID=id;touching=true;
}
static void added(void *ctx,IOReturn result,void *sender,IOHIDDeviceRef device){
    (void)ctx;(void)sender;if(result==kIOReturnSuccess&&!active){
        active=device;x=y=0;touching=false;
        IOHIDDeviceRegisterInputReportCallback(device,reportBuffer,sizeof(reportBuffer),report,device);
    }
}
static void removed(void *ctx,IOReturn result,void *sender,IOHIDDeviceRef device){
    (void)ctx;(void)result;(void)sender;if(device==active){input_enable(false);for(int i=0;i<19;i++)buttons[i]=false;active=NULL;}
}
void input_start(void){
    manager=IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
    int vendor=0x054c,product=0x0ce6;
    CFNumberRef v=CFNumberCreate(NULL,kCFNumberIntType,&vendor),p=CFNumberCreate(NULL,kCFNumberIntType,&product);
    const void *ks[]={CFSTR(kIOHIDVendorIDKey),CFSTR(kIOHIDProductIDKey)};
    const void *vs[]={v,p};
    CFDictionaryRef match=CFDictionaryCreate(NULL,ks,vs,2,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    IOHIDManagerSetDeviceMatching(manager,match);CFRelease(match);CFRelease(v);CFRelease(p);
    IOHIDManagerRegisterDeviceMatchingCallback(manager,added,NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(manager,removed,NULL);
    IOHIDManagerRegisterInputValueCallback(manager,value,NULL);
    IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),kCFRunLoopDefaultMode);
    IOHIDManagerOpen(manager,kIOHIDOptionsTypeNone);
}
void input_tick(double dt,double speed,double dz){
    if(!enabled||!active)return;
    double r=hypot(x,y);if(r<=dz)return;
    double magnitude=fmin(1,(r-dz)/(1-dz));magnitude*=magnitude;
    move_pointer(x/r*magnitude*speed*dt,y/r*magnitude*speed*dt);
}
static void move_pointer(double dx,double dy){
    if(!enabled || !active || pointerSuppressed)return;
    CGPoint p=position();p.x+=dx;p.y+=dy;
    // Clamp to the union of active displays, including monitors with negative coordinates.
    CGDirectDisplayID displays[32];uint32_t count=0;CGRect bounds=CGRectNull;
    if(CGGetActiveDisplayList(32,displays,&count)==kCGErrorSuccess)
        for(uint32_t i=0;i<count;i++)bounds=CGRectUnion(bounds,CGDisplayBounds(displays[i]));
    if(!CGRectIsNull(bounds)){p.x=fmax(CGRectGetMinX(bounds),fmin(CGRectGetMaxX(bounds)-1,p.x));p.y=fmax(CGRectGetMinY(bounds),fmin(CGRectGetMaxY(bounds)-1,p.y));}
    CGEventType type=held[0]?kCGEventLeftMouseDragged:held[1]?kCGEventRightMouseDragged:kCGEventMouseMoved;
    CGEventRef e=CGEventCreateMouseEvent(NULL,type,p,held[0]?kCGMouseButtonLeft:held[1]?kCGMouseButtonRight:kCGMouseButtonLeft);
    if(e){CGEventPost(kCGHIDEventTap,e);CFRelease(e);}
}
bool input_connected(void){return active!=NULL;}
bool input_enabled(void){return enabled;}
void input_stop(void){input_enable(false);if(manager){IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),kCFRunLoopDefaultMode);IOHIDManagerClose(manager,0);CFRelease(manager);manager=NULL;}active=NULL;}
