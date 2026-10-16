use crate::{
    appearance::{Background, IconStyle},
    dock::DockView,
    native,
    state::StudioState,
    ui::Workspace,
};
use gpui::{AsyncApp, Entity, Timer, WindowHandle};
use std::{path::PathBuf, time::Duration};

async fn take(
    window: gpui::AnyWindowHandle,
    path: PathBuf,
    cx: &mut AsyncApp,
) -> Result<(), String> {
    let owner = window
        .update(cx, |_, w, _| native::capture_owner(w))
        .map_err(|e| e.to_string())??;
    let description = native::prepare_capture(&owner);
    Timer::after(Duration::from_millis(100)).await;
    let address = window
        .update(cx, |_, window, _| {
            window.refresh();
            native::view_address(window)
        })
        .map_err(|e| e.to_string())??;
    native::force_draw(address);
    Timer::after(Duration::from_millis(80)).await;
    window
        .update(cx, |_, window, _| native::verify_viewport(window))
        .map_err(|e| e.to_string())??;
    let number = window
        .update(cx, |_, window, _| native::DockNative::window_number(window))
        .map_err(|e| e.to_string())??;
    let output = std::process::Command::new("/usr/sbin/screencapture")
        .args(["-x", "-l", &number.to_string()])
        .arg(path)
        .output()
        .map_err(|e| e.to_string())?;
    if !output.status.success() {
        return Err(format!(
            "Screenshot failed for window {number} ({description}): {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }
    Ok(())
}
pub async fn run(
    window: WindowHandle<Workspace>,
    dock: WindowHandle<DockView>,
    state: Entity<StudioState>,
    cx: &mut AsyncApp,
) -> Result<(), String> {
    let output = PathBuf::from(
        std::env::var("DOCKSTUDIO_CAPTURE_DIR")
            .unwrap_or_else(|_| "/tmp/dockstudio-gpui-capture".into()),
    );
    std::fs::create_dir_all(&output).map_err(|e| e.to_string())?;
    Timer::after(Duration::from_millis(800)).await;
    for (section, name) in [(0, "custom-dock"), (1, "settings"), (2, "profiles")] {
        state
            .update(cx, |s, cx| {
                s.section = section;
                cx.notify();
            })
            .map_err(|e| e.to_string())?;
        take(window.into(), output.join(format!("{name}.png")), cx).await?;
    }
    state
        .update(cx, |s, cx| {
            s.section = 1;
            cx.notify();
        })
        .map_err(|e| e.to_string())?;
    window
        .update(cx, |workspace, _, cx| {
            workspace.capture_scroll(-670.);
            cx.notify();
        })
        .map_err(|e| e.to_string())?;
    take(window.into(), output.join("settings-appearance.png"), cx).await?;
    state
        .update(cx, |s, cx| {
            s.section = 0;
            s.dock_visible = true;
            cx.notify();
        })
        .map_err(|e| e.to_string())?;
    take(dock.into(), output.join("dock-original.png"), cx).await?;
    for (style, name) in [
        (IconStyle::Monochrome, "dock-monochrome"),
        (IconStyle::Glass, "dock-glass"),
    ] {
        state
            .update(cx, |s, cx| {
                let mut appearance = s.appearance.clone();
                appearance.icon_style = style;
                s.save_appearance(appearance, cx);
            })
            .map_err(|e| e.to_string())?;
        take(dock.into(), output.join(format!("{name}.png")), cx).await?;
    }
    state
        .update(cx, |s, cx| {
            let mut appearance = s.appearance.clone();
            appearance.icon_style = IconStyle::Original;
            appearance.background = Background::Transparent;
            s.save_appearance(appearance, cx);
        })
        .map_err(|e| e.to_string())?;
    take(dock.into(), output.join("dock-transparent.png"), cx).await?;
    state
        .update(cx, |s, cx| {
            let mut appearance = s.appearance.clone();
            appearance.background = Background::System;
            s.save_appearance(appearance, cx);
        })
        .map_err(|e| e.to_string())?;
    let frames = output.join("frames");
    std::fs::create_dir_all(&frames).map_err(|e| e.to_string())?;
    for frame in 0..60usize {
        let (from, to, hidden) = match frame / 12 {
            0 => (None, Some(0), None),
            1 => (Some(0), Some(1), None),
            2 => (Some(1), None, None),
            3 => (None, None, Some(true)),
            _ => (None, None, Some(false)),
        };
        dock.update(cx, |view, _, cx| {
            view.capture_animation(
                from,
                to,
                Duration::from_millis(((frame % 12) * 40) as u64),
                hidden,
                cx,
            )
        })
        .map_err(|e| e.to_string())?;
        take(
            dock.into(),
            frames.join(format!("frame-{frame:03}.png")),
            cx,
        )
        .await?;
    }
    dock.update(cx, |view, _, cx| view.capture_hover(None, cx))
        .map_err(|e| e.to_string())?;
    window
        .update(cx, |workspace, _, cx| workspace.capture_hover(None, cx))
        .map_err(|e| e.to_string())?;
    state
        .update(cx, |s, cx| {
            s.dock_visible = false;
            cx.notify();
        })
        .map_err(|e| e.to_string())?;
    println!(
        "Captured GPUI screens and 60 transition frames at {}",
        output.display()
    );
    Ok(())
}
