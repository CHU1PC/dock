use crate::appearance::IconStyle;
use gpui::RenderImage;
use image::Frame;
use std::{collections::HashMap, sync::Arc};

#[derive(Default)]
pub struct IconCache {
    images: HashMap<(String, IconStyle, std::time::SystemTime), Arc<RenderImage>>,
}
impl IconCache {
    pub fn get(&mut self, path: &str, style: IconStyle) -> Option<Arc<RenderImage>> {
        let modified = std::fs::metadata(path).ok()?.modified().ok()?;
        self.images
            .retain(|(p, s, time), _| p != path || *s != style || *time == modified);
        if self.images.len() > 256 {
            self.images.clear();
        }
        let key = (path.to_owned(), style, modified);
        if let Some(image) = self.images.get(&key) {
            return Some(image.clone());
        }
        let mut pixels = image::open(path).ok()?.thumbnail(256, 256).into_rgba8();
        for pixel in pixels.pixels_mut() {
            transform_pixel(&mut pixel.0, style);
            pixel.0.swap(0, 2);
        }
        let image = Arc::new(RenderImage::new(vec![Frame::new(pixels)]));
        self.images.insert(key, image.clone());
        Some(image)
    }
}
pub fn transform_pixel(pixel: &mut [u8; 4], style: IconStyle) {
    let [r, g, b, a] = *pixel;
    let luminance = ((299 * u32::from(r) + 587 * u32::from(g) + 114 * u32::from(b)) / 1000) as u8;
    match style {
        IconStyle::Original => {}
        IconStyle::Monochrome => *pixel = [luminance, luminance, luminance, a],
        IconStyle::Glass => {
            let tone = 175 + (u16::from(luminance) * 80 / 255) as u8;
            *pixel = [
                tone,
                tone.saturating_add(2),
                tone.saturating_add(6),
                ((u16::from(a) * (130 + u16::from(luminance) / 3)) / 255) as u8,
            ];
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn styles_preserve_transparent_pixels() {
        for style in [IconStyle::Original, IconStyle::Monochrome, IconStyle::Glass] {
            let mut p = [128, 30, 200, 0];
            transform_pixel(&mut p, style);
            assert_eq!(p[3], 0);
        }
    }
    #[test]
    fn monochrome_preserves_alpha_and_uses_equal_channels() {
        let mut p = [250, 100, 20, 150];
        transform_pixel(&mut p, IconStyle::Monochrome);
        assert_eq!(p[0], p[1]);
        assert_eq!(p[1], p[2]);
        assert_eq!(p[3], 150);
    }
    #[test]
    fn glass_retains_a_visible_silhouette() {
        let mut p = [0, 0, 0, 255];
        transform_pixel(&mut p, IconStyle::Glass);
        assert!(p[0] > 150);
        assert!(p[3] > 100 && p[3] < 255);
    }
}
