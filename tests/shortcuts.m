#import "../ShortcutRecorder.h"
#include <assert.h>
static NSEvent *event(unsigned short key, NSEventModifierFlags flags, NSString *text, BOOL repeat){
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:0 context:nil characters:text charactersIgnoringModifiers:text isARepeat:repeat keyCode:key];
}
int main(void){@autoreleasepool{
    NSDictionary *s=PadMacShortcutFromEvent(event(1,NSEventModifierFlagCommand|NSEventModifierFlagShift|NSEventModifierFlagCapsLock,@"s",NO));
    assert([s[@"label"] isEqualToString:@"⇧⌘S"]);
    assert([s[@"keycode"] intValue]==1);
    assert([s[@"modifiers"] unsignedLongLongValue]==(NSEventModifierFlagCommand|NSEventModifierFlagShift));
    assert([PadMacShortcutFromEvent(event(53,0,@"",NO))[@"label"] isEqualToString:@"Esc"]);
    assert([PadMacShortcutFromEvent(event(123,NSEventModifierFlagControl|NSEventModifierFlagOption,@"",NO))[@"label"] isEqualToString:@"⌃⌥←"]);
    assert([PadMacShortcutFromEvent(event(122,0,@"",NO))[@"label"] isEqualToString:@"F1"]);
    assert(!PadMacShortcutFromEvent(event(55,NSEventModifierFlagCommand,@"",NO)));
    assert(!PadMacShortcutFromEvent(event(1,0,@"s",YES)));
    NSEvent *chord=[NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint modifierFlags:NSEventModifierFlagOption|NSEventModifierFlagShift timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:56];
    NSDictionary *modifiersOnly=PadMacShortcutFromEvent(chord);
    assert([modifiersOnly[@"keycode"] intValue]==-1);
    assert([modifiersOnly[@"label"] isEqualToString:@"⌥⇧"]);
    assert([modifiersOnly[@"modifiers"] unsignedLongLongValue]==(NSEventModifierFlagOption|NSEventModifierFlagShift));
    NSString *suite=[@"local.padmac.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *d=[[NSUserDefaults alloc] initWithSuiteName:suite];
    [d setInteger:1 forKey:@"action0"];[d setInteger:11 forKey:@"action15"];[d setObject:@"/Applications/Test.app" forKey:@"app15"];
    [d setInteger:3 forKey:@"map1"];[d setInteger:10 forKey:@"action2"];
    PadMacMigrateShortcuts(d);
    assert([d integerForKey:@"action0"]==12);
    assert([[d dictionaryForKey:@"shortcut0"][@"label"] isEqualToString:@"⌘C"]);
    assert([d integerForKey:@"action1"]==12);
    assert([[d dictionaryForKey:@"shortcut1"][@"keycode"] intValue]==49);
    assert([d integerForKey:@"action2"]==10);
    assert([d integerForKey:@"action15"]==11);
    assert([[d stringForKey:@"app15"] isEqualToString:@"/Applications/Test.app"]);
    [d setObject:@{@"keycode":@1,@"modifiers":@0,@"label":@"S"} forKey:@"shortcut0"];
    PadMacMigrateShortcuts(d);assert([[d dictionaryForKey:@"shortcut0"][@"label"] isEqualToString:@"S"]);
    [d removePersistentDomainForName:suite];
    puts("PASS: arbitrary combinations, special keys, ignored repeats/modifiers, preference migration");
}return 0;}
