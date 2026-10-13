#define PADMAC_INPUT_TEST
#include "../input.c"
#include <assert.h>
#include <stdio.h>
static int scrollEvents,pointerEvents,totalVertical,totalHorizontal;
void input_test_scroll(int vertical,int horizontal){scrollEvents++;totalVertical+=vertical;totalHorizontal+=horizontal;}
void input_test_pointer(double dx,double dy){assert(dx!=0||dy!=0);pointerEvents++;}
int main(void){
    active=(IOHIDDeviceRef)(uintptr_t)1;input_enable(true);
    x=0;y=1;input_scroll_mode(true);assert(input_scroll_active());
    input_tick(1.0/60,1100,0.12);
    assert(scrollEvents==1&&totalVertical==-15&&totalHorizontal==0&&pointerEvents==0);
    x=1;y=0;input_tick(1.0/60,1100,0.12);
    assert(scrollEvents==2&&totalHorizontal==-15&&pointerEvents==0);
    x=0;y=-1;input_tick(1.0/60,1100,0.12);assert(totalVertical==0);
    x=-1;y=0;input_tick(1.0/60,1100,0.12);assert(totalHorizontal==0);
    x=0.01;y=0.01;int previous=scrollEvents;input_tick(1.0/60,1100,0.12);assert(scrollEvents==previous);
    // Small deltas accumulate instead of being rounded to zero each frame.
    input_scroll_mode(false);input_scroll_mode(true);x=0;y=0.3;
    for(int i=0;i<20;i++)input_tick(1.0/120,1100,0.12);
    assert(scrollEvents>previous&&pointerEvents==0);
    int before=totalVertical;input_set_scroll_speed(1800);x=0;y=1;
    input_tick(1.0/60,1100,0.12);assert(totalVertical-before==-30);
    before=totalVertical;input_set_scroll_speed(450);
    input_tick(1.0/30,1100,0.12);assert(totalVertical-before==-15);
    input_set_scroll_speed(NAN);assert(scrollSpeed==450);
    input_set_scroll_speed(0);assert(scrollSpeed==100);
    input_set_scroll_speed(4000);assert(scrollSpeed==3000);
    input_set_scroll_speed(900);
    input_scroll_mode(false);assert(!input_scroll_active());x=1;y=0;
    input_tick(1.0/60,1100,0.12);assert(pointerEvents==1);
    input_scroll_mode(true);input_suppress_pointer(true);previous=scrollEvents;
    input_tick(1.0/60,1100,0.12);assert(scrollEvents==previous&&!input_scroll_active());
    input_suppress_pointer(false);input_release_actions();assert(!input_scroll_active());
    input_scroll_mode(true);input_enable(false);assert(!input_scroll_active());
    input_scroll_mode(true);assert(!input_scroll_active());
    input_enable(true);input_scroll_mode(true);removed(NULL,0,NULL,active);assert(!input_scroll_active());
    input_stop();
    puts("PASS: R1 scroll mode, vertical/horizontal directions, adjustable sensitivity, bounds, smooth fractions, deadzone, cursor restore, safety reset");
    return 0;
}
