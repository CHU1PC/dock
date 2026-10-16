#[derive(Debug, Clone, Copy)]
pub struct Metrics {
    pub length: f32,
    pub thickness: f32,
}
pub fn viewport(
    unscaled_length: f32,
    base: f32,
    max_scale: f32,
    available: f32,
    vertical: bool,
) -> Metrics {
    Metrics {
        length: (unscaled_length + (max_scale - 1.0) * base * 3.0)
            .min(available.max(120.0))
            .max(120.0),
        thickness: base + 28.0 + base * (max_scale - 1.0) + if vertical { 120.0 } else { 42.0 },
    }
}
pub fn should_hide(
    auto_hide: bool,
    hovered: bool,
    menu: bool,
    busy: bool,
    elapsed: std::time::Duration,
) -> bool {
    auto_hide && !hovered && !menu && !busy && elapsed > std::time::Duration::from_secs(1)
}
pub fn contains(rect: (f64, f64, f64, f64), x: f64, y: f64) -> bool {
    x >= rect.0 && x <= rect.0 + rect.2 && y >= rect.1 && y <= rect.1 + rect.3
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn viewport_is_bounded_and_reserves_magnification() {
        let idle = viewport(600.0, 52.0, 1.5, 1000.0, false);
        assert_eq!(idle.length, 678.0);
        assert_eq!(viewport(2000.0, 52.0, 1.5, 800.0, false).length, 800.0);
        assert!(idle.thickness > 52.0 * 1.5);
    }
    #[test]
    fn autohide_respects_reveal_and_interaction() {
        use std::time::Duration;
        assert!(!should_hide(true, false, false, false, Duration::ZERO));
        assert!(should_hide(
            true,
            false,
            false,
            false,
            Duration::from_secs(2)
        ));
        assert!(!should_hide(
            true,
            true,
            false,
            false,
            Duration::from_secs(2)
        ));
        assert!(!should_hide(
            true,
            false,
            true,
            false,
            Duration::from_secs(2)
        ));
        assert!(!should_hide(
            true,
            false,
            false,
            true,
            Duration::from_secs(2)
        ));
    }
    #[test]
    fn hit_region_excludes_empty_viewport() {
        assert!(contains((10.0, 0.0, 100.0, 8.0), 50.0, 4.0));
        assert!(!contains((10.0, 0.0, 100.0, 8.0), 50.0, 40.0));
    }
}
