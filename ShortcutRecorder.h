#import <Cocoa/Cocoa.h>
NSDictionary *PadMacShortcutFromEvent(NSEvent *event);
NSString *PadMacShortcutLabel(NSDictionary *shortcut);
NSDictionary *PadMacRecordShortcut(NSDictionary *existing);
void PadMacMigrateShortcuts(NSUserDefaults *defaults);
