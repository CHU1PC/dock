use crate::appearance::{Appearance, Background};
use gpui::{Bounds, Pixels, Window};
use objc2::{
    class, msg_send,
    rc::Retained,
    runtime::{AnyClass, AnyObject},
};
use objc2_app_kit::{NSVisualEffectBlendingMode, NSVisualEffectMaterial, NSVisualEffectState};
use objc2_foundation::{NSPoint, NSRect, NSSize};
use raw_window_handle::{HasWindowHandle, RawWindowHandle};
use std::sync::{Arc, Mutex};

#[derive(Clone, Copy, Default)]
struct HitRegion {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}
fn ns_window(window: &Window) -> Result<*mut AnyObject, String> {
    let handle = HasWindowHandle::window_handle(window).map_err(|e| e.to_string())?;
    let RawWindowHandle::AppKit(handle) = handle.as_raw() else {
        return Err("Expected an AppKit window".into());
    };
    let view = handle.ns_view.as_ptr().cast::<AnyObject>();
    let pointer: *mut AnyObject = unsafe { msg_send![view, window] };
    if pointer.is_null() {
        return Err("Window view is not attached".into());
    }
    Ok(pointer)
}
fn pointer_inside(window: *mut AnyObject, region: HitRegion) -> bool {
    unsafe {
        let point: NSPoint = msg_send![class!(NSEvent), mouseLocation];
        let frame: NSRect = msg_send![window, frame];
        let x = point.x - frame.origin.x;
        let y = point.y - frame.origin.y;
        crate::layout::contains((region.x, region.y, region.width, region.height), x, y)
    }
}
pub fn set_frame(window: &Window, bounds: Bounds<Pixels>) -> Result<(), String> {
    let pointer = ns_window(window)?;
    unsafe {
        let screens: *mut AnyObject = msg_send![class!(NSScreen), screens];
        let count: usize = msg_send![screens, count];
        if count == 0 {
            return Ok(());
        }
        let screen: *mut AnyObject = msg_send![screens,objectAtIndex:0usize];
        let screen_frame: NSRect = msg_send![screen, frame];
        let width: f32 = bounds.size.width.into();
        let height: f32 = bounds.size.height.into();
        let x: f32 = bounds.origin.x.into();
        let y: f32 = bounds.origin.y.into();
        let rect = NSRect::new(
            NSPoint::new(
                f64::from(x),
                screen_frame.size.height - f64::from(y + height),
            ),
            NSSize::new(f64::from(width), f64::from(height)),
        );
        let owner = Retained::retain(pointer).ok_or("Unable to retain window")?;
        let block = block2::RcBlock::new(move || {
            let pointer = &*owner;
            let current: NSRect = msg_send![pointer, frame];
            if (current.origin.x - rect.origin.x).abs() > 0.5
                || (current.origin.y - rect.origin.y).abs() > 0.5
                || (current.size.width - rect.size.width).abs() > 0.5
                || (current.size.height - rect.size.height).abs() > 0.5
            {
                let _: () = msg_send![pointer,setFrame:rect, display:true];
            }
        });
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: () = msg_send![queue, addOperationWithBlock:&*block];
    }
    Ok(())
}
pub fn order(window: &Window, visible: bool) -> Result<(), String> {
    let owner = unsafe { Retained::retain(ns_window(window)?) }.ok_or("Unable to retain window")?;
    let block = block2::RcBlock::new(move || unsafe {
        let pointer = &*owner;
        let current: bool = msg_send![pointer, isVisible];
        if current != visible {
            if visible {
                let _: () = msg_send![pointer,orderFront:nil_object()];
            } else {
                let _: () = msg_send![pointer,orderOut:nil_object()];
            }
        }
    });
    unsafe {
        let queue: *mut AnyObject = msg_send![class!(NSOperationQueue), mainQueue];
        let _: () = msg_send![queue,addOperationWithBlock:&*block];
    }
    Ok(())
}

fn nil_object() -> *mut AnyObject {
    std::ptr::null_mut()
}

pub struct DockNative {
    pointer: *mut AnyObject,
    _owner: Retained<AnyObject>,
    effect: Option<Retained<AnyObject>>,
    monitor: Option<Retained<AnyObject>>,
    hit: Arc<Mutex<HitRegion>>,
    glass: bool,
}
impl DockNative {
    pub fn new(window: &Window) -> Result<Self, String> {
        let pointer = ns_window(window)?;
        let owner = unsafe { Retained::retain(pointer) }.ok_or("Unable to retain Dock window")?;
        let hit = Arc::new(Mutex::new(HitRegion::default()));
        let monitor_hit = hit.clone();
        let address = pointer as usize;
        let block = block2::RcBlock::new(move |_: *mut AnyObject| {
            if let Ok(region) = monitor_hit.lock() {
                let pointer = address as *mut AnyObject;
                unsafe {
                    let _: () =
                        msg_send![pointer,setIgnoresMouseEvents:!pointer_inside(pointer,*region)];
                }
            }
        });
        let monitor = unsafe {
            let monitor: *mut AnyObject = msg_send![class!(NSEvent),addGlobalMonitorForEventsMatchingMask:32usize, handler:&*block];
            Retained::retain(monitor)
        };
        unsafe {
            let _: () = msg_send![pointer,setLevel:3isize];
            let _: () = msg_send![pointer,setHasShadow:false];
            let _: () = msg_send![pointer,setHidesOnDeactivate:false];
        }
        Ok(Self {
            pointer,
            _owner: owner,
            effect: None,
            monitor,
            hit,
            glass: false,
        })
    }
    pub fn update(&mut self, bar: NSRect, interactive: NSRect, appearance: &Appearance) {
        if let Ok(mut hit) = self.hit.lock() {
            *hit = HitRegion {
                x: interactive.origin.x,
                y: interactive.origin.y,
                width: interactive.size.width,
                height: interactive.size.height,
            };
        }
        let enabled = appearance.background != Background::Transparent && appearance.blur;
        unsafe {
            if enabled && self.effect.is_none() {
                let (effect_class, glass) = match AnyClass::get(c"NSGlassEffectView") {
                    Some(class) => (class, true),
                    None => (class!(NSVisualEffectView), false),
                };
                let allocated: *mut AnyObject = msg_send![effect_class, alloc];
                let effect: *mut AnyObject = msg_send![allocated,initWithFrame:bar];
                if let Some(effect) = Retained::from_raw(effect) {
                    if glass {
                        let _: () = msg_send![&*effect,setCornerRadius:22.0f64];
                    } else {
                        let _: () = msg_send![&*effect,setMaterial:NSVisualEffectMaterial::UnderWindowBackground];
                        let _: () = msg_send![&*effect,setBlendingMode:NSVisualEffectBlendingMode::BehindWindow];
                        let _: () = msg_send![&*effect,setState:NSVisualEffectState::Active];
                        let _: () = msg_send![&*effect,setWantsLayer:true];
                        let layer: *mut AnyObject = msg_send![&*effect, layer];
                        if !layer.is_null() {
                            let _: () = msg_send![layer,setCornerRadius:22.0f64];
                            let _: () = msg_send![layer,setMasksToBounds:true];
                        }
                    }
                    let content: *mut AnyObject = msg_send![self.pointer, contentView];
                    let _: () = msg_send![content,addSubview:&*effect, positioned:-1isize, relativeTo:nil_object()];
                    self.effect = Some(effect);
                    self.glass = glass;
                }
            }
            if let Some(effect) = &self.effect {
                let _: () = msg_send![&**effect,setHidden:!enabled];
                let _: () = msg_send![&**effect,setFrame:bar];
                let alpha = if appearance.background == Background::System {
                    appearance.opacity
                } else {
                    1.0
                };
                let _: () = msg_send![&**effect,setAlphaValue:f64::from(alpha)];
            }
        }
        self.update_pointer();
    }
    pub fn update_pointer(&self) {
        if let Ok(hit) = self.hit.lock() {
            unsafe {
                let _: () = msg_send![self.pointer,setIgnoresMouseEvents:!pointer_inside(self.pointer,*hit)];
            }
        }
    }
    pub fn hovered(&self) -> bool {
        self.hit
            .lock()
            .map(|hit| pointer_inside(self.pointer, *hit))
            .unwrap_or(false)
    }
    pub fn window_number(window: &Window) -> Result<isize, String> {
        let pointer = ns_window(window)?;
        Ok(unsafe { msg_send![pointer, windowNumber] })
    }
}
impl Drop for DockNative {
    fn drop(&mut self) {
        unsafe {
            if let Some(monitor) = &self.monitor {
                let _: () = msg_send![class!(NSEvent),removeMonitor:&**monitor];
            }
            if let Some(effect) = &self.effect {
                let _: () = msg_send![&**effect, removeFromSuperview];
            }
        }
    }
}

pub fn capture_mode() {
    unsafe {
        let app: *mut AnyObject = msg_send![class!(NSApplication), sharedApplication];
        let _: bool = msg_send![app,setActivationPolicy:2isize];
    }
}

pub fn view_address(window: &Window) -> Result<usize, String> {
    let handle = HasWindowHandle::window_handle(window).map_err(|e| e.to_string())?;
    let RawWindowHandle::AppKit(handle) = handle.as_raw() else {
        return Err("Expected AppKit".into());
    };
    Ok(handle.ns_view.as_ptr() as usize)
}
pub fn force_draw(address: usize) {
    unsafe {
        let view = address as *mut AnyObject;
        let layer: *mut AnyObject = msg_send![view, layer];
        let _: () = msg_send![view,displayLayer:layer];
    }
}

pub fn startup_error(message: &str) {
    unsafe {
        let app: *mut AnyObject = msg_send![class!(NSApplication), sharedApplication];
        let _: bool = msg_send![app,setActivationPolicy:1isize];
        let _: () = msg_send![app,activateIgnoringOtherApps:true];
        let alert: Retained<AnyObject> = msg_send![class!(NSAlert), new];
        let _: () = msg_send![&*alert,setMessageText:&*objc2_foundation::NSString::from_str("Dock Studio を起動できませんでした")];
        let _: () =
            msg_send![&*alert,setInformativeText:&*objc2_foundation::NSString::from_str(message)];
        let _: isize = msg_send![&*alert, runModal];
    }
}

pub fn verify_viewport(window: &Window) -> Result<(), String> {
    let view = view_address(window)? as *mut AnyObject;
    let rect: NSRect = unsafe { msg_send![view, bounds] };
    let size = window.viewport_size();
    let w: f32 = size.width.into();
    let h: f32 = size.height.into();
    if (rect.size.width - f64::from(w)).abs() > 1.0 || (rect.size.height - f64::from(h)).abs() > 1.0
    {
        return Err(format!(
            "Viewport mismatch: native={}x{}, GPUI={}x{}",
            rect.size.width, rect.size.height, w, h
        ));
    }
    Ok(())
}

pub fn capture_owner(window: &Window) -> Result<Retained<AnyObject>, String> {
    unsafe { Retained::retain(ns_window(window)?).ok_or("Unable to retain capture window".into()) }
}
pub fn prepare_capture(owner: &AnyObject) -> String {
    unsafe {
        let visible: bool = msg_send![owner, isVisible];
        if !visible {
            let _: () = msg_send![owner,setAlphaValue:0.0f64];
            let _: () = msg_send![owner,setFrameOrigin:NSPoint::new(-20000.0,20000.0)];
            let _: () = msg_send![owner,orderFront:nil_object()];
            let _: () = msg_send![owner,setFrameOrigin:NSPoint::new(-20000.0,20000.0)];
            let _: () = msg_send![owner,setAlphaValue:1.0f64];
        }
        let rect: NSRect = msg_send![owner, frame];
        format!("frame={rect:?}")
    }
}
#[link(name = "CoreGraphics", kind = "framework")]
unsafe extern "C" {
    fn CGSessionCopyCurrentDictionary() -> *mut AnyObject;
}
pub fn capture_session_ready() -> Result<(), String> {
    unsafe {
        let dictionary = Retained::from_raw(CGSessionCopyCurrentDictionary())
            .ok_or("No graphical login session is available")?;
        let locked: *mut AnyObject = msg_send![&*dictionary,objectForKey:&*objc2_foundation::NSString::from_str("CGSSessionScreenIsLocked")];
        if !locked.is_null() {
            let value: bool = msg_send![locked, boolValue];
            if value {
                return Err("Screen capture is unavailable while macOS is locked. Unlock the Mac and retry; capture windows remain offscreen.".into());
            }
        }
        Ok(())
    }
}
