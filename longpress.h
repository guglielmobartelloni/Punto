#pragma once
#include <stdbool.h>
#define HOLD_DELAY 0.45
typedef enum {HOLD_PRIMARY_DOWN,HOLD_PRIMARY_UP,HOLD_ALTERNATE_DOWN,HOLD_ALTERNATE_UP} HoldEvent;
typedef void (*HoldHandler)(int index,HoldEvent event);
void longpress_button(int index,bool pressed,double now,HoldHandler handler);
void longpress_tick(double now,HoldHandler handler);
void longpress_cancel(HoldHandler handler);
