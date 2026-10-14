#include "../launcher.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    LauncherState state;launcher_reset(&state);assert(!state.visible&&state.direction==-1&&state.slot==-1);
    bool available[4][2]={{true,true},{true,false},{false,true},{false,false}};
    launcher_select(&state,0,available);assert(state.visible&&state.direction==0&&state.slot==0);
    launcher_select(&state,0,available);assert(state.slot==1);
    launcher_select(&state,0,available);assert(state.slot==0);
    launcher_select(&state,1,available);assert(state.direction==1&&state.slot==0);
    launcher_select(&state,1,available);assert(state.slot==0);
    launcher_select(&state,2,available);assert(state.direction==2&&state.slot==1);
    launcher_select(&state,2,available);assert(state.slot==1);
    launcher_select(&state,3,available);assert(state.direction==3&&state.slot==0);
    launcher_select(&state,3,available);assert(state.slot==0);
    launcher_select(&state,-1,available);launcher_select(&state,4,available);assert(state.direction==3);
    launcher_reset(&state);launcher_select(&state,0,available);assert(state.slot==0);
    bool full[4][2]={{true,true},{true,true},{true,true},{true,true}};
    for(int direction=0;direction<4;direction++){
        launcher_reset(&state);launcher_select(&state,direction,full);launcher_select(&state,direction,full);
        int opposite=(direction+2)%4;
        launcher_select(&state,opposite,full);assert(state.direction==direction&&state.slot==0);
        launcher_select(&state,opposite,full);assert(state.direction==opposite&&state.slot==0);
    }
    launcher_reset(&state);launcher_select(&state,2,available);assert(state.slot==1);
    launcher_select(&state,0,available);assert(state.direction==0&&state.slot==0); // Skip an empty inner slot.
    launcher_reset(&state);launcher_select(&state,0,full);launcher_select(&state,0,full);
    launcher_select(&state,1,full);assert(state.direction==1&&state.slot==0); // Perpendicular input switches arms.
    puts("PASS: directional selection, cycling, opposite-direction inward step, arm crossing, sparse slots, reset");return 0;
}
