#import "UINavigation.h"
#import "navigation.h"
#include <stdatomic.h>

static id attribute(AXUIElementRef element,CFStringRef name){
    AXUIElementSetMessagingTimeout(element,0.025);
    CFTypeRef value=NULL;
    if(AXUIElementCopyAttributeValue(element,name,&value)!=kAXErrorSuccess)return nil;
    return CFBridgingRelease(value);
}
static CGRect elementFrame(AXUIElementRef element){
    id position=attribute(element,kAXPositionAttribute),size=attribute(element,kAXSizeAttribute);
    CGPoint p;CGSize s;
    if(!position||!size||CFGetTypeID((__bridge CFTypeRef)position)!=AXValueGetTypeID()||CFGetTypeID((__bridge CFTypeRef)size)!=AXValueGetTypeID())return CGRectZero;
    if(!AXValueGetValue((__bridge AXValueRef)position,kAXValueCGPointType,&p)||!AXValueGetValue((__bridge AXValueRef)size,kAXValueCGSizeType,&s))return CGRectZero;
    if(!isfinite(p.x)||!isfinite(p.y)||!isfinite(s.width)||!isfinite(s.height)||s.width<2||s.height<2)return CGRectZero;
    return (CGRect){p,s};
}
static BOOL sameElement(id a,id b){return a&&b&&CFEqual((__bridge CFTypeRef)a,(__bridge CFTypeRef)b);}
static id focusedRoot(AXUIElementRef app,id *window,id *focused){
    *window=attribute(app,kAXFocusedWindowAttribute);*focused=attribute(app,kAXFocusedUIElementAttribute);
    id root=*window;
    id ancestor=*focused;
    for(int depth=0;ancestor&&depth<12;depth++){
        NSString *role=attribute((__bridge AXUIElementRef)ancestor,kAXRoleAttribute);
        if([role isEqual:@"AXMenu"]||[role isEqual:@"AXSheet"])return ancestor;
        ancestor=attribute((__bridge AXUIElementRef)ancestor,kAXParentAttribute);
    }
    // Sheets are children of their window in the public AX hierarchy.
    NSArray *children=root?attribute((__bridge AXUIElementRef)root,kAXChildrenAttribute):nil;
    if([children isKindOfClass:NSArray.class])for(NSUInteger i=0;i<MIN(children.count,(NSUInteger)32);i++){
        if([attribute((__bridge AXUIElementRef)children[i],kAXRoleAttribute) isEqual:@"AXSheet"])return children[i];
    }
    return root;
}

@interface PuntoHighlightPanel : NSPanel @end
@implementation PuntoHighlightPanel
- (BOOL)canBecomeKeyWindow{return NO;}
- (BOOL)canBecomeMainWindow{return NO;}
@end
@interface PuntoHighlightView : NSView @end
@implementation PuntoHighlightView
- (void)drawRect:(NSRect)dirtyRect{
    (void)dirtyRect;[[NSColor colorWithRed:0.94 green:0.32 blue:0.36 alpha:1] setStroke];
    NSBezierPath *path=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,2,2) xRadius:7 yRadius:7];path.lineWidth=3;[path stroke];
}
@end
@interface PuntoUINavigation () { atomic_bool _active; }
@property(nonatomic,readwrite) NSString *status;
@property(nonatomic) dispatch_queue_t queue;
@property(atomic) NSUInteger generation;
@property(nonatomic) BOOL busy;
@property(nonatomic) NSMutableArray<NSNumber *> *commands;
@property(nonatomic) id selected;
@property(nonatomic) id scope;
@property(nonatomic) pid_t selectedPID;
@property(nonatomic) PuntoHighlightPanel *highlight;
@property(nonatomic) PuntoHighlightPanel *messagePanel;
@property(nonatomic) NSUInteger messageVersion;
@property(nonatomic) double lastPoll;
@end
@implementation PuntoUINavigation
- (instancetype)init{
    if((self=[super init])){
        atomic_init(&_active,false);
        _queue=dispatch_queue_create("local.punto.accessibility",DISPATCH_QUEUE_SERIAL);
        _commands=[NSMutableArray new];_status=@"UI navigation is paused.";
        _highlight=[[PuntoHighlightPanel alloc] initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
        _highlight.opaque=NO;_highlight.backgroundColor=NSColor.clearColor;_highlight.hasShadow=NO;
        _highlight.level=NSStatusWindowLevel;_highlight.ignoresMouseEvents=YES;_highlight.hidesOnDeactivate=NO;
        _highlight.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;
        _highlight.contentView=[PuntoHighlightView new];[_highlight.contentView setAccessibilityElement:NO];
        _messagePanel=[[PuntoHighlightPanel alloc] initWithContentRect:NSMakeRect(0,0,480,56) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
        _messagePanel.opaque=NO;_messagePanel.backgroundColor=[NSColor colorWithWhite:0.12 alpha:0.95];_messagePanel.hasShadow=YES;
        _messagePanel.level=NSStatusWindowLevel;_messagePanel.ignoresMouseEvents=YES;_messagePanel.hidesOnDeactivate=NO;
        _messagePanel.collectionBehavior=_highlight.collectionBehavior;
        _messagePanel.contentView.wantsLayer=YES;_messagePanel.contentView.layer.cornerRadius=10;
        _messagePanel.contentView.layer.masksToBounds=YES;[_messagePanel.contentView setAccessibilityElement:NO];
    }return self;
}
- (void)clearSelection{
    self.selected=nil;self.scope=nil;self.selectedPID=0;[self.highlight orderOut:nil];[self.messagePanel orderOut:nil];
}
- (BOOL)isActive{return atomic_load(&_active);}
- (void)setActive:(BOOL)active{
    if(atomic_exchange(&_active,active)==active)return;
    self.generation++;[self.commands removeAllObjects];[self clearSelection];
    self.status=active?@"Press a direction to select a control.":@"UI navigation is paused.";
    if(active)[self showMessage:@"D-pad / Left stick selects · ✕ activates · ○ goes back"];
}
- (void)showMessage:(NSString *)message{
    NSTextField *label=[NSTextField labelWithString:message];label.frame=NSMakeRect(16,10,448,36);
    label.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];label.textColor=NSColor.whiteColor;
    label.alignment=NSTextAlignmentCenter;label.maximumNumberOfLines=2;[label setAccessibilityElement:NO];
    for(NSView *view in self.messagePanel.contentView.subviews)[view removeFromSuperview];
    [self.messagePanel.contentView addSubview:label];
    NSRect screen=(NSScreen.mainScreen?:NSScreen.screens.firstObject).visibleFrame;
    [self.messagePanel setFrameOrigin:NSMakePoint(NSMidX(screen)-240,NSMinY(screen)+28)];[self.messagePanel orderFrontRegardless];
    NSUInteger version=++self.messageVersion;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(version==self.messageVersion)[self.messagePanel orderOut:nil];});
}
- (void)move:(NSInteger)direction{if(direction>=0&&direction<4)[self enqueue:direction];}
- (void)stopStickNavigation{
    for(NSInteger i=(NSInteger)self.commands.count-1;i>=0;i--)if(self.commands[i].integerValue>=10)[self.commands removeObjectAtIndex:(NSUInteger)i];
}
- (void)moveFromStick:(NSInteger)direction{
    if(!self.active||direction<0||direction>3)return;
    [self stopStickNavigation];
    if(self.busy){if(self.commands.count<8)[self.commands addObject:@(10+direction)];}
    else [self request:direction];
}
- (void)activateSelection{[self enqueue:4];}
- (void)goBack{[self enqueue:5];}
- (void)enqueue:(NSInteger)command{
    if(!self.active)return;
    if(self.busy){if(self.commands.count<8)[self.commands addObject:@(command)];return;}
    [self request:command];
}
- (void)drain{
    if(!self.active||self.busy||!self.commands.count)return;
    NSInteger command=self.commands.firstObject.integerValue;[self.commands removeObjectAtIndex:0];[self request:command>=10?command-10:command];
}
- (void)poll{
    double now=NSProcessInfo.processInfo.systemUptime;
    if(!self.active||self.busy||!self.selected||now-self.lastPoll<0.25)return;
    self.lastPoll=now;[self request:6];
}
- (void)showFrame:(CGRect)frame{
    // AX uses top-left global coordinates; AppKit uses bottom-left coordinates.
    CGFloat top=NSMaxY(NSScreen.screens.firstObject.frame);
    NSRect rect=NSMakeRect(frame.origin.x-4,top-CGRectGetMaxY(frame)-4,frame.size.width+8,frame.size.height+8);
    [self.highlight setFrame:rect display:YES];[self.highlight orderFrontRegardless];
}
- (pid_t)frontmostPID{return NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;}
- (void)request:(NSInteger)command{
    if(!self.active||!AXIsProcessTrusted()){[self clearSelection];return;}
    pid_t pid=[self frontmostPID];
    if(pid<=0){[self clearSelection];return;}
    if(command==4||command==5){[self.highlight orderOut:nil];[self.messagePanel orderOut:nil];}
    self.busy=YES;NSUInteger generation=self.generation;
    id oldSelected=self.selected,oldScope=self.scope;pid_t oldPID=self.selectedPID;
    NSString *oldStatus=self.status;
    NSMutableArray *screenRects=[NSMutableArray new];CGFloat top=NSMaxY(NSScreen.screens.firstObject.frame);
    for(NSScreen *screen in NSScreen.screens){NSRect r=screen.frame;[screenRects addObject:[NSValue valueWithRect:NSMakeRect(r.origin.x,top-NSMaxY(r),r.size.width,r.size.height)]];}
    dispatch_async(self.queue,^{
        AXUIElementRef app=AXUIElementCreateApplication(pid);
        id window=nil,focused=nil;
        id root=focusedRoot(app,&window,&focused);
        BOOL sameScope=oldPID==pid&&sameElement(oldScope,root);
        BOOL scopeChanged=oldScope&&!sameScope;
        NSString *status=@"No accessible controls in this window.";id chosen=nil;CGRect chosenFrame=CGRectZero;BOOL escape=NO;
        BOOL permitted=self.active&&self.generation==generation&&AXIsProcessTrusted()&&[self frontmostPID]==pid;
        if(command==5&&permitted){
            AXUIElementRef target=(__bridge AXUIElementRef)(sameScope&&oldSelected?oldSelected:root);
            id latestWindow=attribute(app,kAXFocusedWindowAttribute);
            permitted=self.active&&self.generation==generation&&AXIsProcessTrusted()&&[self frontmostPID]==pid&&(sameElement(latestWindow,window)||(!latestWindow&&!window));
            if(target)AXUIElementSetMessagingTimeout(target,0.5);
            AXError error=target&&permitted?AXUIElementPerformAction(target,kAXCancelAction):kAXErrorActionUnsupported;
            escape=permitted&&(error==kAXErrorActionUnsupported||error==kAXErrorNotImplemented);
            status=error==kAXErrorSuccess||escape?@"Back":@"Back action could not be completed.";
        }else if(command==6&&root&&sameScope&&oldSelected){
            chosenFrame=elementFrame((__bridge AXUIElementRef)oldSelected);
            CGRect bounds=elementFrame((__bridge AXUIElementRef)root);
            if(!CGRectIsEmpty(bounds))chosenFrame=CGRectIntersection(chosenFrame,bounds);
            id parent=attribute((__bridge AXUIElementRef)oldSelected,kAXParentAttribute);
            double deadline=NSProcessInfo.processInfo.systemUptime+0.08;
            for(int depth=0;parent&&depth<12&&NSProcessInfo.processInfo.systemUptime<deadline;depth++){
                if([attribute((__bridge AXUIElementRef)parent,kAXRoleAttribute) isEqual:@"AXScrollArea"]){
                    CGRect viewport=elementFrame((__bridge AXUIElementRef)parent);
                    if(!CGRectIsEmpty(viewport))chosenFrame=CGRectIntersection(chosenFrame,viewport);
                }
                if(sameElement(parent,root))break;
                parent=attribute((__bridge AXUIElementRef)parent,kAXParentAttribute);
            }
            if(!CGRectIsEmpty(chosenFrame)&&(CGRectIsEmpty(bounds)||CGRectIntersectsRect(bounds,chosenFrame))&&![attribute((__bridge AXUIElementRef)oldSelected,CFSTR("AXHidden")) boolValue]&&![attribute((__bridge AXUIElementRef)oldSelected,kAXEnabledAttribute) isEqual:@NO]){
                chosen=oldSelected;status=oldStatus;
            }else status=@"Selection changed. Press a direction to select again.";
        }else if(command!=6&&root&&permitted){
            NSMutableArray<NSDictionary *> *controls=[NSMutableArray new];
            CGRect rootFrame=elementFrame((__bridge AXUIElementRef)root);
            NSMutableArray *pending=[NSMutableArray arrayWithObject:@{@"element":root,@"clip":[NSValue valueWithRect:rootFrame]}];
            NSMutableSet *visited=[NSMutableSet new];NSUInteger cursor=0;
            double deadline=NSProcessInfo.processInfo.systemUptime+0.3;
            while(cursor<pending.count&&cursor<2000&&NSProcessInfo.processInfo.systemUptime<deadline){
                NSDictionary *entry=pending[cursor++];id element=entry[@"element"];
                if([visited containsObject:element])continue;[visited addObject:element];
                AXUIElementRef ax=(__bridge AXUIElementRef)element;
                if([attribute(ax,CFSTR("AXHidden")) boolValue])continue;
                NSString *role=attribute(ax,kAXRoleAttribute);CGRect frame=elementFrame(ax),clip=[entry[@"clip"] rectValue];
                BOOL visible=!CGRectIsEmpty(frame)&&(CGRectIsEmpty(clip)||CGRectIntersectsRect(frame,clip));
                BOOL onScreen=NO;for(NSValue *r in screenRects)if(CGRectIntersectsRect(frame,r.rectValue)){onScreen=YES;break;}
                if(visible&&onScreen&&![attribute(ax,kAXEnabledAttribute) isEqual:@NO]){
                    CFArrayRef names=NULL;AXUIElementCopyActionNames(ax,&names);NSArray *actions=CFBridgingRelease(names);
                    NSString *action=nil;for(NSString *candidate in @[@"AXPress",@"AXConfirm",@"AXPick"])if([actions containsObject:candidate]){action=candidate;break;}
                    Boolean focusable=false;AXUIElementIsAttributeSettable(ax,kAXFocusedAttribute,&focusable);
                    if(focusable&&([role isEqual:@"AXTextField"]||[role isEqual:@"AXTextArea"]))action=nil;
                    BOOL input=[@[@"AXTextField",@"AXTextArea",@"AXComboBox",@"AXSlider",@"AXCheckBox",@"AXRadioButton",@"AXButton",@"AXPopUpButton",@"AXLink",@"AXRow",@"AXCell",@"AXTab"] containsObject:role];
                    if(action||(focusable&&input)){
                        NSString *title=attribute(ax,kAXTitleAttribute);if(![title isKindOfClass:NSString.class]||!title.length)title=attribute(ax,kAXDescriptionAttribute);
                        if(![title isKindOfClass:NSString.class]||!title.length)title=[role hasPrefix:@"AX"]?[role substringFromIndex:2]:@"Control";
                        if(title.length>120)title=[[title substringToIndex:120] stringByAppendingString:@"…"];
                        [controls addObject:@{@"element":element,@"frame":[NSValue valueWithRect:CGRectIsEmpty(clip)?frame:CGRectIntersection(frame,clip)],@"action":action?:@"",@"title":title}];
                    }
                }
                NSArray *children=attribute(ax,kAXVisibleChildrenAttribute);if(![children isKindOfClass:NSArray.class])children=attribute(ax,kAXChildrenAttribute);
                if([role isEqual:@"AXScrollArea"]&&!CGRectIsEmpty(frame))clip=CGRectIsEmpty(clip)?frame:CGRectIntersection(clip,frame);
                if([children isKindOfClass:NSArray.class])for(id child in children){
                    if(pending.count>=2000)break;
                    if(CFGetTypeID((__bridge CFTypeRef)child)==AXUIElementGetTypeID())[pending addObject:@{@"element":child,@"clip":[NSValue valueWithRect:clip]}];
                }
            }
            int current=-1,initial=-1;
            for(NSUInteger i=0;i<controls.count;i++){
                if(sameScope&&sameElement(controls[i][@"element"],oldSelected))current=(int)i;
                if(sameElement(controls[i][@"element"],focused))initial=(int)i;
            }
            if(command==4){
                if(current<0)status=@"Selection changed. Press a direction to select again.";
                else{
                    NSDictionary *control=controls[current];AXUIElementRef target=(__bridge AXUIElementRef)control[@"element"];
                    NSString *action=control[@"action"];
                    // Recheck the app and scope just before acting; never click coordinates.
                    id latestWindow=nil,latestFocused=nil;
                    id latestRoot=focusedRoot(app,&latestWindow,&latestFocused);
                    BOOL valid=self.active&&self.generation==generation&&AXIsProcessTrusted()&&[self frontmostPID]==pid&&sameElement(latestRoot,root);
                    AXUIElementSetMessagingTimeout(target,0.5); // Native button animations can outlast attribute reads.
                    AXError error=valid?(action.length?AXUIElementPerformAction(target,(__bridge CFStringRef)action):AXUIElementSetAttributeValue(target,kAXFocusedAttribute,kCFBooleanTrue)):kAXErrorInvalidUIElement;
                    status=error==kAXErrorSuccess?@"Activated. Press a direction to continue.":!valid?@"Window changed. Press a direction to select again.":[NSString stringWithFormat:@"This control could not be activated (AX %d). Try another control or the mouse.",(int)error];
                    // Some providers report Failure even after dispatching the action. Never retry it.
                    BOOL uncertain=valid&&(error==kAXErrorFailure||error==kAXErrorCannotComplete);
                    if(uncertain)status=@"Action requested. If nothing happens, try the mouse.";
                    // Keep selection for actions that leave the same control visible.
                    if(error==kAXErrorSuccess||uncertain){
                        id afterWindow=nil,afterFocused=nil;id afterRoot=focusedRoot(app,&afterWindow,&afterFocused);
                        CGRect frame=elementFrame(target);
                        if(sameElement(afterRoot,root)&&!CGRectIsEmpty(frame)&&![attribute(target,kAXEnabledAttribute) isEqual:@NO]&&![attribute(target,CFSTR("AXHidden")) boolValue]){
                            chosen=control[@"element"];chosenFrame=frame;status=[(uncertain?@"Action requested: ":@"Selected: ") stringByAppendingString:control[@"title"]];
                        }
                    }
                }
            }else{
                int next=current;
                if(command<4){
                    if(current<0)next=initial>=0?initial:(controls.count?0:-1);
                    else{
                        NavigationRect rects[2000];for(NSUInteger i=0;i<controls.count;i++){CGRect r=[controls[i][@"frame"] rectValue];rects[i]=(NavigationRect){r.origin.x,r.origin.y,r.size.width,r.size.height};}
                        int neighbor=navigation_neighbor(rects,controls.count,current,(int)command);if(neighbor>=0)next=neighbor;
                    }
                }
                if(next>=0){chosen=controls[next][@"element"];chosenFrame=[controls[next][@"frame"] rectValue];status=[@"Selected: " stringByAppendingString:controls[next][@"title"]];}
                else if(command==6)status=@"Selection changed. Press a direction to select again.";
            }
        }
        CFRelease(app);
        dispatch_async(dispatch_get_main_queue(),^{
            self.busy=NO;
            if(self.active&&generation==self.generation&&AXIsProcessTrusted()&&[self frontmostPID]==pid){
                if(scopeChanged)[self.commands removeAllObjects];
                self.status=status;self.selected=chosen;self.scope=root;self.selectedPID=pid;
                if(chosen)[self showFrame:chosenFrame];else [self.highlight orderOut:nil];
                if(!chosen&&(command<5||(command==5&&![status isEqual:@"Back"])))[self showMessage:status];
                if(escape&&self.backFallback)self.backFallback();
            }else{[self.commands removeAllObjects];[self clearSelection];if(self.active)self.status=@"Window changed. Press a direction to select again.";}
            [self drain];
        });
    });
}
@end
