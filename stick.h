#ifndef PUNTO_STICK_H
#define PUNTO_STICK_H
#include <stdbool.h>
typedef struct { bool armed; int direction; double repeatAt; } StickNavigation;
void stick_navigation_reset(StickNavigation *state);
// Normalized HID axes; returns up/right/down/left (0..3), or -1.
int stick_navigation_step(StickNavigation *state,double x,double y,double now,bool repeat);
#endif
