#include "../navigation.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    NavigationRect grid[]={{100,100,50,30},{100,40,50,30},{170,100,50,30},{100,160,50,30},{30,100,50,30},{130,130,50,30},{100,100,50,30},{160,100,0,30}};
    assert(navigation_neighbor(grid,8,0,0)==1);
    assert(navigation_neighbor(grid,8,0,1)==2);
    assert(navigation_neighbor(grid,8,0,2)==3);
    assert(navigation_neighbor(grid,8,0,3)==4);
    assert(navigation_neighbor(grid,8,1,0)==-1);
    assert(navigation_neighbor(grid,8,-1,0)==-1);
    assert(navigation_neighbor(grid,8,9,0)==-1);
    assert(navigation_neighbor(grid,8,0,4)==-1);
    assert(navigation_neighbor(NULL,0,0,0)==-1);
    NavigationRect negative[]={{-300,-100,40,40},{-200,-100,40,40}};
    assert(navigation_neighbor(negative,2,0,1)==1);
    NavigationRect sideways[]={{100,100,50,30},{110,300,50,30}};
    assert(navigation_neighbor(sideways,2,0,1)==-1);
    puts("PASS: four directions, row/column preference, direction cone, boundaries, overlapping and invalid rectangles, multiple displays");
}
