#pragma once
#include <stdbool.h>
void input_start(void);
void input_stop(void);
void input_tick(double seconds, double speed, double deadzone);
void input_enable(bool enabled);
void input_release_actions(void);
void input_suppress_pointer(bool suppressed);
void input_scroll_mode(bool active);
bool input_scroll_active(void);
void input_set_scroll_speed(double pixels_per_second);
bool input_connected(void);
bool input_enabled(void);
void input_shortcut(int index, int keycode, unsigned long long modifiers);
void input_mapping(int index, int keycode, unsigned long long modifiers);
void input_modifier_shortcut(unsigned long long modifiers);
void input_default_button(int index,bool pressed);
// Return true to override defaults; receives press/release and index=-1 on reset.
typedef bool (*InputButtonHandler)(int index, bool pressed);
void input_button_handler(InputButtonHandler handler);
