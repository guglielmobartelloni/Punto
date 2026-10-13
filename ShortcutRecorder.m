#import "ShortcutRecorder.h"

static NSString *keyName(NSEvent *event){
    NSDictionary *special=@{@36:@"↩",@48:@"⇥",@49:@"Space",@51:@"⌫",@53:@"Esc",@76:@"Keypad Enter",@117:@"⌦",@123:@"←",@124:@"→",@125:@"↓",@126:@"↑",@115:@"Home",@119:@"End",@116:@"Page Up",@121:@"Page Down",@122:@"F1",@120:@"F2",@99:@"F3",@118:@"F4",@96:@"F5",@97:@"F6",@98:@"F7",@100:@"F8",@101:@"F9",@109:@"F10",@103:@"F11",@111:@"F12",@105:@"F13",@107:@"F14",@113:@"F15",@106:@"F16",@64:@"F17",@79:@"F18",@80:@"F19",@90:@"F20"};
    NSString *name=special[@(event.keyCode)];
    if(name)return name;
    NSString *characters=event.charactersIgnoringModifiers.uppercaseString;
    return characters.length?characters:[NSString stringWithFormat:@"Key %u",event.keyCode];
}
// Translate legacy display labels without changing saved keycodes or modifiers.
NSString *PadMacShortcutLabel(NSDictionary *shortcut){
    NSString *label=shortcut[@"label"];if(![label isKindOfClass:NSString.class])return nil;
    NSDictionary *legacy=@{@"Spazio":@"Space",@"Invio numerico":@"Keypad Enter",@"Fine":@"End",@"Pagina su":@"Page Up",@"Pagina giù":@"Page Down"};
    for(NSString *suffix in legacy)if([label hasSuffix:suffix]){
        return [[label substringToIndex:label.length-suffix.length] stringByAppendingString:legacy[suffix]];
    }
    if([label hasPrefix:@"Tasto "])return [@"Key " stringByAppendingString:[label substringFromIndex:6]];
    return label;
}
NSDictionary *PadMacShortcutFromEvent(NSEvent *event){
    BOOL modifierOnly=event.type==NSEventTypeFlagsChanged;
    if(!modifierOnly && (event.type!=NSEventTypeKeyDown || event.isARepeat))return nil;
    if(!modifierOnly){
        switch(event.keyCode){case 54:case 55:case 56:case 57:case 58:case 59:case 60:case 61:case 62:case 63:return nil;default:break;}
    }
    NSEventModifierFlags flags=event.modifierFlags & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagFunction);
    if(modifierOnly && !flags)return nil;
    NSMutableString *label=[NSMutableString new];
    if(flags&NSEventModifierFlagControl)[label appendString:@"⌃"];
    if(flags&NSEventModifierFlagOption)[label appendString:@"⌥"];
    if(flags&NSEventModifierFlagShift)[label appendString:@"⇧"];
    if(flags&NSEventModifierFlagCommand)[label appendString:@"⌘"];
    if(flags&NSEventModifierFlagFunction)[label appendString:@"fn "];
    if(!modifierOnly)[label appendString:keyName(event)];
    return @{@"keycode":modifierOnly?@(-1):@(event.keyCode),@"modifiers":@(flags),@"label":label};
}
NSDictionary *PadMacRecordShortcut(NSDictionary *existing){
    NSAlert *alert=[NSAlert new];alert.messageText=@"Record a shortcut";
    alert.informativeText=@"Press a keyboard combination, then click Save. You can also record a single key or a modifier-only chord. Use Cancel to dismiss this dialog.";
    [alert addButtonWithTitle:@"Save"];[alert addButtonWithTitle:@"Cancel"];
    // Return and Escape must be recordable rather than activating dialog buttons.
    for(NSButton *button in alert.buttons)button.keyEquivalent=@"";
    alert.buttons[0].enabled=NO;
    NSTextField *display=[NSTextField labelWithString:PadMacShortcutLabel(existing)?:@"Waiting for your shortcut…"];
    display.frame=NSMakeRect(0,0,350,55);display.alignment=NSTextAlignmentCenter;display.font=[NSFont systemFontOfSize:23 weight:NSFontWeightMedium];alert.accessoryView=display;
    __block NSDictionary *captured=nil;
    __block NSEventModifierFlags previousFlags=0;
    id monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskFlagsChanged handler:^NSEvent *(NSEvent *event){
        if(event.window!=alert.window)return event;
        NSDictionary *shortcut=PadMacShortcutFromEvent(event);
        if(event.type==NSEventTypeFlagsChanged){
            NSEventModifierFlags flags=event.modifierFlags & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagFunction);
            // Keep the complete chord when its keys are released one at a time.
            if(!(flags & ~previousFlags))shortcut=nil;
            previousFlags=flags;
        }
        if(shortcut){captured=shortcut;display.stringValue=shortcut[@"label"];alert.buttons[0].enabled=YES;}
        return nil; // Consume locally: do not run menu commands such as Command-Q.
    }];
    NSModalResponse response;
    @try{response=[alert runModal];}@finally{[NSEvent removeMonitor:monitor];}
    return response==NSAlertFirstButtonReturn?captured:nil;
}
void PadMacMigrateShortcuts(NSUserDefaults *d){
    if([d boolForKey:@"recordedShortcutSchema"])return;
    int keys[]={8,9,36,49,6,0,3,48,53};
    NSArray *labels=@[@"⌘C",@"⌘V",@"↩",@"Space",@"⌘Z",@"⌘A",@"⌘F",@"⌘⇥",@"Esc"];
    for(int i=0;i<19;i++){
        if(i==9)continue;
        NSString *actionKey=[NSString stringWithFormat:@"action%d",i];NSInteger action=[d integerForKey:actionKey];
        NSInteger old=-1;
        if(action>=1&&action<=9)old=action-1;
        if(action==0&&i<4){
            NSNumber *previous=[d objectForKey:[NSString stringWithFormat:@"map%d",i]];
            if(previous)old=previous.integerValue;
        }
        if(old>=0&&old<=8){
            unsigned long long modifiers=(old==2||old==3||old==8)?0:NSEventModifierFlagCommand;
            [d setObject:@{@"keycode":@(keys[old]),@"modifiers":@(modifiers),@"label":labels[old]} forKey:[NSString stringWithFormat:@"shortcut%d",i]];
            [d setInteger:12 forKey:actionKey];
        }
    }
    [d setBool:YES forKey:@"recordedShortcutSchema"];
}
