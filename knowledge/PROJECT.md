# Project context

This repository is a simple Jekyll static site that lists art prints from product folders.

## Data and assets

- Product source data lives in `_products/<slug>/`.
- Each product folder contains `index.md` (front matter metadata) and `image.jpg` (source image).
- A derivative step generates `image-square-320.jpg`, `image-square-580.jpg`, and `image-square-900.jpg` per product.
- Generated thumbnails `image-square-*.jpg` are ignored in git and built in CI.
- Use `bundle exec rake images` to regenerate thumbnails locally.
- Each product `index.md` uses a `versions` list to capture techniques with per-size prices.

## Output

- The site is a single page (`index.html`) with a product grid using the default layout.
- Rendering uses the `products` collection (`site.products`).
- Styling is in `assets/css/site.css`.
- Client-side sorting is available for name and price (low/high), plus a size filter dropdown; controls are hidden in print.
