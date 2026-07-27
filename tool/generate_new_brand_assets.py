from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "new_assets"
SPLASH = ROOT / "assets" / "splash"
LOGOS = ROOT / "assets" / "logos"
WHITE = (255, 255, 255, 255)


def trim_visible_alpha(
    image: Image.Image,
    *,
    threshold: int = 8,
    padding: int = 24,
) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= threshold else 0)
    bbox = visible.getbbox()
    if bbox is None:
        raise ValueError("Image source entièrement transparente")

    left, top, right, bottom = bbox
    return rgba.crop(
        (
            max(0, left - padding),
            max(0, top - padding),
            min(rgba.width, right + padding),
            min(rgba.height, bottom + padding),
        )
    )


def contain(image: Image.Image, size: int, inset: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), WHITE)
    content_size = size - (inset * 2)
    fitted = image.copy()
    fitted.thumbnail((content_size, content_size), Image.Resampling.LANCZOS)
    x = (size - fitted.width) // 2
    y = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (x, y))
    return canvas


def normalize_near_white(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = (
        (255, 255, 255, alpha)
        if red >= 248 and green >= 248 and blue >= 248
        else (red, green, blue, alpha)
        for red, green, blue, alpha in rgba.get_flattened_data()
    )
    rgba.putdata(list(pixels))
    return rgba


def main() -> None:
    SPLASH.mkdir(parents=True, exist_ok=True)
    icon = normalize_near_white(Image.open(SOURCE / "app-icon.png"))
    logo = trim_visible_alpha(Image.open(SOURCE / "logo-name.png"))

    contain(icon, 1024, 0).convert("RGB").save(
        LOGOS / "app_icon_source.png",
        optimize=True,
    )
    contain(icon, 1024, 0).save(
        SPLASH / "app_icon_native.png",
        optimize=True,
    )
    contain(icon, 1152, 192).save(
        SPLASH / "app_icon_android12.png",
        optimize=True,
    )

    logo.thumbnail((1200, 420), Image.Resampling.LANCZOS)
    logo.save(SPLASH / "logo_name.png", optimize=True)


if __name__ == "__main__":
    main()
