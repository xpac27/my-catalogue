#!/usr/bin/env ruby

require "fileutils"

products_root = File.join(__dir__, "..", "_products")
target_sizes = [320, 580, 900]
max_side_output = "image-max-1000.jpg"
max_side_limit = 1000

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

  dims = IO.popen([image_tool, source, "-format", "%w %h", "info:"], &:read).to_s.strip
  width, height = dims.split.map(&:to_i)
  largest_side = [width, height].max
  max_side_path = File.join(folder, max_side_output)

  if largest_side <= max_side_limit
    FileUtils.cp(source, max_side_path)
  else
    ok = system(
      image_tool,
      source,
      "-auto-orient",
      "-resize", "#{max_side_limit}x#{max_side_limit}>",
      "-strip",
      "-interlace", "Plane",
      "-quality", "88",
      max_side_path
    )
    unless ok
      warn "Failed to build #{max_side_path}"
      exit 1
    end
  end
end
