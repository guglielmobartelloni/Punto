#ifndef PUNTO_NAVIGATION_H
#define PUNTO_NAVIGATION_H
#include <stddef.h>
typedef struct { double x,y,width,height; } NavigationRect;
// Screen coordinates: y increases downward. Directions: up, right, down, left.
int navigation_neighbor(const NavigationRect *rects,size_t count,int current,int direction);
#endif
