#pragma once
#include <stdbool.h>
typedef struct {bool visible;int direction;int slot;} LauncherState;
void launcher_reset(LauncherState *state);
void launcher_select(LauncherState *state,int direction,const bool available[4][2]);
