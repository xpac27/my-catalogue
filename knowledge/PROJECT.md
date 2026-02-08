# Project context

This repository is a simple Jekyll static site that lists art prints from a catalogue submodule.

## Data and assets

- Product source data lives in `catalogues/virginie-prints-catalogue/_products/<slug>/`.
- Each product folder contains `index.md` (front matter metadata) and `image.jpg` (source image).
- A derivative step generates public assets in `catalogues/virginie-prints-catalogue/products-assets/<slug>/`.
- Public assets include `image-square-320.jpg`, `image-square-580.jpg`, `image-square-900.jpg`, `image-max-1000.jpg`, and optional `image-max-1000_*.jpg`.
- Generated public assets are ignored in the catalogue submodule git repo and built in CI.
- Use `bundle exec rake images` to regenerate thumbnails locally.
- Each product `index.md` uses a `versions` list to capture techniques with per-size prices.

## Output

- The site is a single page (`index.html`) with a product grid using the default layout.
- Rendering uses the `products` collection (`site.products`).
- Styling is in `assets/css/site.css`.
- Client-side sorting is available for name and price (low/high), plus a size filter dropdown; controls are hidden in print.
