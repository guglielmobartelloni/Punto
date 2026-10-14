#include "../stick.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void){
    StickNavigation s;stick_navigation_reset(&s);
    assert(stick_navigation_step(&s,1,0,0,true)==-1); // Must recenter after reset.
    assert(stick_navigation_step(&s,0,0,0,true)==-1);
    assert(stick_navigation_step(&s,0.4,0,0.1,true)==-1);
    assert(stick_navigation_step(&s,1,0,1,true)==1);
    assert(stick_navigation_step(&s,1,0,1.37,true)==-1);
    assert(stick_navigation_step(&s,1,0,1.39,true)==1);
    assert(stick_navigation_step(&s,1,0,1.5,true)==-1);
    assert(stick_navigation_step(&s,1,0,1.58,true)==1);
    assert(stick_navigation_step(&s,0,1,1.6,true)==2);
    assert(stick_navigation_step(&s,0.9,1,1.7,true)==-1); // Diagonal noise keeps the current sector.
    assert(stick_navigation_step(&s,1,0.6,1.71,true)==1);
    assert(stick_navigation_step(&s,0,-1,1.8,true)==0);
    assert(stick_navigation_step(&s,-1,0,1.9,true)==3);
    assert(stick_navigation_step(&s,0.2,0,2,true)==-1);
    assert(stick_navigation_step(&s,0,-1,2.1,false)==0);
    assert(stick_navigation_step(&s,0,-1,3,false)==-1);
    assert(stick_navigation_step(&s,1,0,4,false)==-1); // Launcher requires another centered tilt.
    assert(stick_navigation_step(&s,0,0,4.1,false)==-1);
    assert(stick_navigation_step(&s,1,0,4.2,false)==1);
    stick_navigation_reset(&s);assert(stick_navigation_step(&s,1,0,5,true)==-1);
    assert(stick_navigation_step(&s,NAN,0,5,true)==-1&&!s.armed);
    assert(stick_navigation_step(&s,0,0,INFINITY,true)==-1&&!s.armed);
    puts("PASS: left-stick directions, drift threshold, sector hysteresis, delayed/repeated steps, launcher single-shot and reset recentering");
}
