#include "launcher.h"
void launcher_reset(LauncherState *state){if(state){state->visible=false;state->direction=-1;state->slot=-1;}}
void launcher_select(LauncherState *state,int direction,const bool available[4][2]){
    if(!state||!available||direction<0||direction>3)return;
    if(state->visible&&state->direction==direction){
        int other=state->slot==0?1:0;
        if(available[direction][other])state->slot=other;
    }else{
        state->direction=direction;state->slot=available[direction][0]?0:available[direction][1]?1:0;
    }
    state->visible=true;
}
