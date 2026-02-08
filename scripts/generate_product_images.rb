#!/usr/bin/env ruby

require "fileutils"

products_root = File.join(__dir__, "..", "_products")
target_sizes = [320, 580, 900]

unless Dir.exist?(products_root)
  warn "Missing #{products_root}"
  exit 1
end

image_tool = nil
if system("magick", "-version", out: File::NULL, err: File::NULL)
  image_tool = "magick"
elsif system("convert", "-version", out: File::NULL, err: File::NULL)
  image_tool = "convert"
end

unless image_tool
  warn "ImageMagick is required ('magick' or 'convert')"
  exit 1
end

Dir.children(products_root).sort.each do |entry|
  folder = File.join(products_root, entry)
  next unless File.directory?(folder)

  source = File.join(folder, "image.jpg")
  unless File.exist?(source)
    warn "Skipping #{entry}: missing image.jpg"
    next
  end

  target_sizes.each do |size|
    output = File.join(folder, "image-square-#{size}.jpg")
    ok = system(
      image_tool,
      source,
      "-auto-orient",
      "-resize", "#{size}x#{size}^",
      "-gravity", "center",
      "-extent", "#{size}x#{size}",
      "-strip",
      "-interlace", "Plane",
      "-quality", "85",
      output
    )
    unless ok
      warn "Failed to build #{output}"
      exit 1
    end
  end
end
