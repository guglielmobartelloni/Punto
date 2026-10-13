#include "../longpress.h"
#include <assert.h>
#include <stdio.h>
static HoldEvent events[32];static int indices[32],count;
static void event(int index,HoldEvent e){assert(count<32);indices[count]=index;events[count++]=e;}
int main(void){
    longpress_button(0,true,0,event);longpress_tick(0.2,event);assert(count==0);
    longpress_button(0,false,0.3,event);assert(count==2&&events[0]==HOLD_PRIMARY_DOWN&&events[1]==HOLD_PRIMARY_UP);
    count=0;longpress_button(0,true,1,event);longpress_tick(1.46,event);
    assert(count==1&&events[0]==HOLD_ALTERNATE_DOWN);
    longpress_tick(2,event);longpress_button(0,true,2,event);assert(count==1);
    longpress_button(0,false,3,event);assert(count==2&&events[1]==HOLD_ALTERNATE_UP);
    count=0;longpress_button(0,true,4,event);longpress_button(0,false,5,event);
    assert(count==2&&events[0]==HOLD_ALTERNATE_DOWN&&events[1]==HOLD_ALTERNATE_UP);
    count=0;longpress_button(0,true,6,event);longpress_cancel(event);longpress_tick(7,event);
    longpress_button(0,false,7,event);assert(count==0);
    longpress_button(1,true,8,event);longpress_button(2,true,8,event);longpress_tick(9,event);
    assert(count==2&&indices[0]==1&&indices[1]==2);
    longpress_cancel(event);assert(count==4&&events[2]==HOLD_ALTERNATE_UP&&events[3]==HOLD_ALTERNATE_UP);
    longpress_cancel(event);assert(count==4);
    puts("PASS: short/long exclusivity, threshold, sustained hold, concurrent buttons, cancellation");return 0;
}
