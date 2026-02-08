# Virginie Prints Listing

Static Jekyll site that renders products from the `_products/` collection.
Each product folder is source data and contains:
- `index.md` front matter with product metadata and versions.
- `image.jpg` original source image.

## Quick start

```bash
bundle install
bundle exec rake serve
```

Then open `http://localhost:4000`.

To generate responsive image derivatives:

```bash
bundle exec rake images
```

This creates `_products/<slug>/image-square-320.jpg`, `_products/<slug>/image-square-580.jpg`, and `_products/<slug>/image-square-900.jpg`.
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
