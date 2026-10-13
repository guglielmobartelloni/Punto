#pragma once
#include <stdbool.h>
void input_start(void);
void input_stop(void);
void input_tick(double seconds, double speed, double deadzone);
void input_enable(bool enabled);
bool input_connected(void);
bool input_enabled(void);
void input_shortcut(int index, int keycode, unsigned long long modifiers);
void input_mapping(int index, int keycode, unsigned long long modifiers);
void input_modifier_shortcut(unsigned long long modifiers);
void input_default_button(int index,bool pressed);
// Return true to override defaults; receives press/release and index=-1 on reset.
typedef bool (*InputButtonHandler)(int index, bool pressed);
void input_button_handler(InputButtonHandler handler);
