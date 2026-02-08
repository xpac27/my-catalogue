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

def image_dimensions(tool, path)
  dims = IO.popen([tool, path, "-format", "%w %h", "info:"], &:read).to_s.strip
  width, height = dims.split.map(&:to_i)
  [width, height]
end

def build_max_side(tool, source, output_path, max_side_limit)
  width, height = image_dimensions(tool, source)
  largest_side = [width, height].max

  if largest_side <= max_side_limit
    FileUtils.cp(source, output_path)
    return true
  end

  system(
    tool,
    source,
    "-auto-orient",
    "-resize", "#{max_side_limit}x#{max_side_limit}>",
    "-strip",
    "-interlace", "Plane",
    "-quality", "88",
    output_path
  )
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

  max_side_path = File.join(folder, max_side_output)

  ok = build_max_side(image_tool, source, max_side_path, max_side_limit)
  unless ok
    warn "Failed to build #{max_side_path}"
    exit 1
  end

  Dir.glob(File.join(folder, "image-max-1000_*.jpg")).each { |path| FileUtils.rm_f(path) }
  additional_sources = Dir.children(folder).select do |filename|
    next false unless filename.match?(/\.(jpe?g|png|webp)\z/i)
    next false if filename == "image.jpg"
    next false if filename.start_with?("image-square-")
    next false if filename == "image-max-1000.jpg"
    next false if filename.match?(/\Aimage-max-1000_\d+\.jpg\z/)

    true
  end.sort

  additional_sources.each_with_index do |filename, index|
    additional_source = File.join(folder, filename)
    additional_output = File.join(folder, "image-max-1000_#{index + 1}.jpg")
    ok = build_max_side(image_tool, additional_source, additional_output, max_side_limit)
    unless ok
      warn "Failed to build #{additional_output}"
      exit 1
    end
  end
end
