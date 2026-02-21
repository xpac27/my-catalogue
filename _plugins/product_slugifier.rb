# frozen_string_literal: true

module ProductSlugifier
  module_function

  def base_name_for(doc)
    dirname = File.basename(File.dirname(doc.relative_path.to_s))
    return dirname unless dirname == "." || dirname.empty?

    File.basename(doc.basename_without_ext.to_s)
  end

  def normalize_slug(text)
    slug = Jekyll::Utils.slugify(text.to_s, mode: "default", cased: false)
    slug.empty? ? "product" : slug
  end
end

Jekyll::Hooks.register :site, :pre_render do |site|
  products = site.collections["products"]
  next unless products

  used = Hash.new(0)

  products.docs.sort_by(&:relative_path).each do |doc|
    next unless doc.extname =~ /\.md|\.markdown/i
    next unless doc.basename_without_ext == "index"

    base_slug = ProductSlugifier.normalize_slug(ProductSlugifier.base_name_for(doc))
    candidate = base_slug

    while used.key?(candidate)
      used[base_slug] += 1
      candidate = "#{base_slug}_#{used[base_slug]}"
    end

    used[candidate] = 0
    doc.data["slug"] = candidate
    doc.data["permalink"] = "/products/#{candidate}/"
  end
end
