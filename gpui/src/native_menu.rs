use objc2::{
    class, msg_send,
    rc::Retained,
    runtime::{AnyObject, ClassBuilder, Sel},
    sel,
};
use objc2_foundation::{NSPoint, NSString};
use std::sync::{Mutex, Once};

#[derive(Clone, Debug)]
pub struct Entry {
    pub label: String,
    pub command: String,
    pub checked: bool,
}
static TRACKING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
pub fn tracking() -> bool {
    TRACKING.load(std::sync::atomic::Ordering::Relaxed)
}
static COMMANDS: Mutex<Vec<String>> = Mutex::new(Vec::new());
pub fn drain() -> Vec<String> {
    COMMANDS
        .lock()
        .map(|mut q| std::mem::take(&mut *q))
        .unwrap_or_default()
}
extern "C" fn selected(_: *mut AnyObject, _: Sel, sender: *mut AnyObject) {
    let command: *mut NSString = unsafe { msg_send![sender, representedObject] };
    if let Some(command) = unsafe { command.as_ref() } {
        if let Ok(mut queue) = COMMANDS.lock() {
            queue.push(command.to_string());
        }
    }
}
fn menu(entries: &[Entry]) -> Retained<AnyObject> {
    static REGISTER: Once = Once::new();
    REGISTER.call_once(|| {
        let mut builder = ClassBuilder::new(c"DockStudioMenuTarget", class!(NSObject))
            .expect("Unique menu class");
        unsafe {
            builder.add_method(
                sel!(selected:),
                selected as extern "C" fn(*mut AnyObject, Sel, *mut AnyObject),
            );
        }
        builder.register();
    });
    unsafe {
        let target: Retained<AnyObject> = msg_send![
            objc2::runtime::AnyClass::get(c"DockStudioMenuTarget").unwrap(),
            new
        ];
        let menu: Retained<AnyObject> = msg_send![class!(NSMenu), new];
        let _: () = msg_send![&*menu, setAutoenablesItems:false];
        for entry in entries {
            let allocated: *mut AnyObject = msg_send![class!(NSMenuItem), alloc];
            let pointer: *mut AnyObject = msg_send![allocated, initWithTitle:&*NSString::from_str(&entry.label), action:sel!(selected:), keyEquivalent:&*NSString::from_str("")];
            let item = Retained::from_raw(pointer).expect("Menu item");
            let _: () = msg_send![&*item, setTarget:&*target];
            let _: () =
                msg_send![&*item, setRepresentedObject:&*NSString::from_str(&entry.command)];
            let _: () = msg_send![&*item, setState:if entry.checked {1isize} else {0isize}];
            let _: () = msg_send![&*menu, addItem:&*item];
        }
        // NSMenuItem does not retain its target. Associate it with the menu.
        objc_setAssociatedObject(
            (&*menu as *const AnyObject).cast_mut(),
            c"DockStudioMenuTarget".as_ptr().cast(),
            (&*target as *const AnyObject).cast_mut(),
            1,
        );
        menu
    }
}
unsafe extern "C" {
    fn objc_setAssociatedObject(
        object: *mut AnyObject,
        key: *const std::ffi::c_void,
        value: *mut AnyObject,
        policy: usize,
    );
}

pub struct StatusMenu {
    item: Retained<AnyObject>,
    signature: Vec<String>,
}
impl StatusMenu {
    pub fn new() -> Self {
        unsafe {
            let bar: *mut AnyObject = msg_send![class!(NSStatusBar), systemStatusBar];
            let pointer: *mut AnyObject = msg_send![bar, statusItemWithLength:-1.0f64];
            let item = Retained::retain(pointer).expect("Status item");
            let button: *mut AnyObject = msg_send![&*item, button];
            let _: () = msg_send![button,setTitle:&*NSString::from_str("▥")];
            let _: () = msg_send![button,setToolTip:&*NSString::from_str("Dock Studio")];
            Self {
                item,
                signature: Vec::new(),
            }
        }
    }
    pub fn update(&mut self, entries: &[Entry]) {
        let signature: Vec<_> = entries
            .iter()
            .map(|e| format!("{}:{}:{}", e.label, e.command, e.checked))
            .collect();
        if self.signature == signature {
            return;
        }
        self.signature = signature;
        let menu = menu(entries);
        unsafe {
            let _: () = msg_send![&*self.item,setMenu:&*menu];
        }
    }
}
impl Drop for StatusMenu {
    fn drop(&mut self) {
        unsafe {
            let bar: *mut AnyObject = msg_send![class!(NSStatusBar), systemStatusBar];
            let _: () = msg_send![bar, removeStatusItem:&*self.item];
        }
    }
}
// Schedule AppKit's modal tracking after GPUI has released the App borrow.
pub fn popup(entries: Vec<Entry>, x: f32, y: f32, view: usize) {
    let view = unsafe { Retained::retain(view as *mut AnyObject) };
    let block = block2::RcBlock::new(move || {
        if let Some(view) = &view {
            let menu = menu(&entries);
            TRACKING.store(true, std::sync::atomic::Ordering::Relaxed);
            unsafe {
                let flipped: bool = msg_send![&**view, isFlipped];
                let bounds: objc2_foundation::NSRect = msg_send![&**view, bounds];
                let y = if flipped {
                    f64::from(y)
                } else {
                    bounds.size.height - f64::from(y)
                };
                let _: bool = msg_send![&*menu, popUpMenuPositioningItem:std::ptr::null_mut::<AnyObject>(), atLocation:NSPoint::new(f64::from(x), y), inView:&**view];
            }
            TRACKING.store(false, std::sync::atomic::Ordering::Relaxed);
        }
    });
    unsafe {
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: () = msg_send![queue, addOperationWithBlock:&*block];
    }
}
pub fn entries(snapshot: &crate::model::Snapshot, visible: bool) -> Vec<Entry> {
    let mut entries = vec![
        Entry {
            label: "設定…".into(),
            command: "settings".into(),
            checked: false,
        },
        Entry {
            label: if visible {
                "Dock を隠す"
            } else {
                "Dock を表示"
            }
            .into(),
            command: "toggle".into(),
            checked: false,
        },
    ];
    entries.extend(snapshot.document.profiles.iter().map(|p| Entry {
        label: p.name.clone(),
        command: format!("profile:{}", p.id),
        checked: p.id == snapshot.document.active_profile_id,
    }));
    entries.push(Entry {
        label: "終了".into(),
        command: "quit".into(),
        checked: false,
    });
    entries
}

pub fn self_check() -> Result<(), String> {
    objc2::rc::autoreleasepool(|_| {
        let entries = vec![
            Entry {
                label: "設定".into(),
                command: "settings".into(),
                checked: false,
            },
            Entry {
                label: "Profile".into(),
                command: "profile:test".into(),
                checked: true,
            },
        ];
        let menu = menu(&entries);
        unsafe {
            let _: () = msg_send![&*menu,performActionForItemAtIndex:0isize];
            let _: () = msg_send![&*menu,performActionForItemAtIndex:1isize];
        }
        let actual = drain();
        if actual != ["settings", "profile:test"] {
            return Err(format!("Native menu commands did not match: {actual:?}"));
        }
        Ok(())
    })
}
