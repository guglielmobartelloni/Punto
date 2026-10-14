#include "navigation.h"
#include <math.h>
#include <float.h>
int navigation_neighbor(const NavigationRect *rects,size_t count,int current,int direction){
    if(!rects||current<0||(size_t)current>=count||direction<0||direction>3)return -1;
    NavigationRect a=rects[current];double best=DBL_MAX;int selected=-1;
    for(size_t i=0;i<count;i++){
        NavigationRect b=rects[i];if((int)i==current||b.width<=0||b.height<=0)continue;
        double dx=b.x+b.width/2-a.x-a.width/2,dy=b.y+b.height/2-a.y-a.height/2;
        double forward=direction==0?-dy:direction==1?dx:direction==2?dy:-dx;
        if(forward<=1)continue;
        double cross=(direction==0||direction==2)?fabs(dx):fabs(dy);
        if(cross>forward*2)continue; // Do not jump mostly sideways to the requested direction.
        double span=(direction==0||direction==2)?(a.width+b.width)/2:(a.height+b.height)/2;
        // Favor controls in the same row/column, while still allowing diagonals.
        double score=forward+cross*2+fmax(0,cross-span)*4;
        if(score<best){best=score;selected=(int)i;}
    }
    return selected;
}
