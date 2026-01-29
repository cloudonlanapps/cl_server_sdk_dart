import sys
import os
import random

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow not installed. Run 'uv pip install Pillow'", file=sys.stderr)
    sys.exit(1)

def make_unique(source_path, dest_path):
    try:
        with Image.open(source_path) as img:
            # Copy to modify
            img_copy = img.copy()
            width, height = img_copy.size
            
            # Modify a random pixel in the last row to avoid visible corruption but change hash
            x = random.randint(0, width - 1)
            y = height - 1
            
            pixel = list(img_copy.getpixel((x, y)))
            # Nudge the first channel (R or L)
            pixel[0] = (pixel[0] + 1) % 256
            
            if img_copy.mode == 'RGBA':
                img_copy.putpixel((x, y), tuple(pixel))
            else:
                img_copy.putpixel((x, y), tuple(pixel[:3]))
            
            # Preserve EXIF
            exif_data = img.getexif()
            
            # Save with high quality to preserve face detection details
            # This also significantly reduces file size compared to raw append
            img_copy.save(dest_path, exif=exif_data, quality=95)
            return True
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python make_unique.py <source> <dest>")
        sys.exit(1)
    
    success = make_unique(sys.argv[1], sys.argv[2])
    sys.exit(0 if success else 1)
