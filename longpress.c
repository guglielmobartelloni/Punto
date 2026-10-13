#include "longpress.h"
static struct {bool pending,triggered;double start;} holds[19];
void longpress_button(int index,bool pressed,double now,HoldHandler handler){
    if(index<0||index>=19||!handler)return;
    if(pressed){
        if(holds[index].pending)return;
        holds[index].pending=true;holds[index].triggered=false;holds[index].start=now;
    }else{
        if(!holds[index].pending)return;
        // Handle a threshold crossing even when the timer has not run yet.
        if(!holds[index].triggered && now-holds[index].start>=HOLD_DELAY){
            holds[index].triggered=true;handler(index,HOLD_ALTERNATE_DOWN);
        }
        bool alternate=holds[index].triggered;holds[index].pending=false;
        if(alternate)handler(index,HOLD_ALTERNATE_UP);
        else{handler(index,HOLD_PRIMARY_DOWN);handler(index,HOLD_PRIMARY_UP);}
    }
}
void longpress_tick(double now,HoldHandler handler){
    if(!handler)return;
    for(int i=0;i<19;i++)if(holds[i].pending&&!holds[i].triggered&&now-holds[i].start>=HOLD_DELAY){
        holds[i].triggered=true;handler(i,HOLD_ALTERNATE_DOWN);
    }
}
void longpress_cancel(HoldHandler handler){
    for(int i=0;i<19;i++){
        bool release=holds[i].pending&&holds[i].triggered;
        holds[i].pending=holds[i].triggered=false;
        if(release&&handler)handler(i,HOLD_ALTERNATE_UP);
    }
}
