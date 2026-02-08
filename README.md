# Virginie Prints Listing

Static Jekyll site that renders products from the catalogue submodule.
Source content lives in `catalogues/virginie-prints-catalogue/_products/`.
Each product folder contains:
- `index.md` front matter with product metadata and versions.
- `image.jpg` original source image.

## Quick start

```bash
git submodule update --init --recursive
bundle install
bundle exec rake serve
```

Then open `http://localhost:4000`.

To generate responsive image derivatives:

```bash
bundle exec rake images
```

This creates derivatives inside the submodule:

- `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-320.jpg`
- `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-580.jpg`
- `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-900.jpg`
- `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-max-1000.jpg`
- `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-max-1000_*.jpg` (for additional source images)
These generated thumbnails are ignored in git and are built in CI during deploy.

Each product file uses a `versions` list in its front matter:

```yaml
versions:
  - technique: "Screen printing"
    sizes:
      - size: "30x40"
        price: 500
  - technique: "Linocut"
    sizes:
      - size: "A5"
        price: 250
```
