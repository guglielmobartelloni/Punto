// Tests exercise input dispatch without posting mouse/keyboard events.
#include "../input.c"
#include <assert.h>
#include <stdio.h>
static int presses[19],releases[19];
static bool consume(int index,bool down){if(index<0)return true;if(down)presses[index]++;else releases[index]++;return true;}
int main(void){
    input_button_handler(consume);
    enabled=true;
    for(int i=0;i<19;i++){
        if(i==9)continue;
        button(i,true);button(i,true);button(i,false);button(i,false);
        assert(presses[i]==1 && releases[i]==1);
    }
    enabled=false;button(15,true);button(15,false);assert(presses[15]==1);
    enabled=true;button(9,true);assert(!enabled);button(9,true);assert(!enabled);
    button(9,false);button(9,true);assert(enabled);assert(presses[9]==0);
    button(9,false);button(-1,true);button(19,true);
    puts("PASS: all button and D-pad slots, press deduplication, suspend, reserved Options");
    return 0;
}
