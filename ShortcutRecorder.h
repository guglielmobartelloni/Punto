#import <Cocoa/Cocoa.h>
NSDictionary *PadMacShortcutFromEvent(NSEvent *event);
NSDictionary *PadMacRecordShortcut(NSDictionary *existing);
void PadMacMigrateShortcuts(NSUserDefaults *defaults);
