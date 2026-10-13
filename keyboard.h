#pragma once
#include <stdbool.h>
void keyboard_hold(int slot,int keycode,unsigned long long modifiers,bool pressed);
void keyboard_release_all(void);
