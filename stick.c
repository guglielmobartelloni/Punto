#include "stick.h"
#include <math.h>
void stick_navigation_reset(StickNavigation *state){*state=(StickNavigation){false,-1,0};}
int stick_navigation_step(StickNavigation *state,double x,double y,double now,bool repeat){
    if(!isfinite(x)||!isfinite(y)||!isfinite(now)){stick_navigation_reset(state);return -1;}
    double ax=fabs(x),ay=fabs(y),magnitude=fmax(ax,ay);
    if(magnitude<=0.30){state->armed=true;state->direction=-1;state->repeatAt=0;return -1;}
    if(!state->armed||magnitude<0.55)return -1;
    int direction=ax>ay?(x>0?1:3):(y>0?2:0);
    // Keep the current sector near diagonals to avoid noisy alternating steps.
    if(state->direction>=0){
        bool horizontal=state->direction==1||state->direction==3;
        bool sameSign=horizontal?(state->direction==1?x>0:x<0):(state->direction==2?y>0:y<0);
        if(sameSign&&(horizontal?ax:ay)>=(horizontal?ay:ax)*0.8)direction=state->direction;
    }
    if(direction!=state->direction){
        state->direction=direction;state->repeatAt=now+0.38;
        if(!repeat)state->armed=false;
        return direction;
    }
    if(repeat&&now>=state->repeatAt){state->repeatAt=now+0.18;return direction;}
    return -1;
}
