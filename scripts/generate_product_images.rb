#!/usr/bin/env ruby

require "etc"
require "fileutils"

products_root = File.join(__dir__, "..", "catalogues", "virginie-prints-catalogue", "_products")
public_root = File.join(__dir__, "..", "catalogues", "virginie-prints-catalogue", "products-assets")
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

def default_image_jobs
  cores = Etc.nprocessors
  [[cores - 1, 1].max, 8].min
rescue StandardError
  2
end

def resolve_job_count(product_count)
  env_value = ENV["IMAGE_JOBS"].to_s.strip
  jobs = env_value.empty? ? default_image_jobs : env_value.to_i
  jobs = 1 if jobs < 1
  [jobs, [product_count, 1].max].min
end

def image_dimensions(tool, path)
  dims = IO.popen([tool, path, "-format", "%w %h", "info:"], &:read).to_s.strip
  width, height = dims.split.map(&:to_i)
  [width, height]
end

def needs_update?(source_path, output_path)
  return true unless File.exist?(output_path)

  File.mtime(source_path) > File.mtime(output_path)
end

def build_max_side(tool, source, output_path, max_side_limit)
  return true unless needs_update?(source, output_path)

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

def process_product(entry:, products_root:, public_root:, target_sizes:, max_side_output:, max_side_limit:, image_tool:)
  folder = File.join(products_root, entry)
  public_folder = File.join(public_root, entry)
  FileUtils.mkdir_p(public_folder)

  source = File.join(folder, "image.jpg")
  unless File.exist?(source)
    return [true, "Skipping #{entry}: missing image.jpg"]
  end

  expected_outputs = []

  target_sizes.each do |size|
    output = File.join(public_folder, "image-square-#{size}.jpg")
    expected_outputs << output
    next unless needs_update?(source, output)

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
      return [false, "Failed to build #{output}"]
    end
  end

  max_side_path = File.join(public_folder, max_side_output)
  expected_outputs << max_side_path

  ok = build_max_side(image_tool, source, max_side_path, max_side_limit)
  unless ok
    return [false, "Failed to build #{max_side_path}"]
  end

  additional_sources = Dir.children(folder).select do |filename|
    next false unless filename.match?(/\.(jpe?g|png|webp)\z/i)
    next false if filename == "image.jpg"
    next false if filename.start_with?("image-square-")
    next false if filename == "image-max-1000.jpg"
    next false if filename.match?(/\Aimage-max-1000_\d+\.jpg\z/)

    true
  end.sort

  expected_outputs += additional_sources.each_with_index.map do |_, index|
    File.join(public_folder, "image-max-1000_#{index + 1}.jpg")
  end

  Dir.glob(File.join(public_folder, "image-max-1000_*.jpg")).each do |path|
    FileUtils.rm_f(path) unless expected_outputs.include?(path)
  end

  additional_sources.each_with_index do |filename, index|
    additional_source = File.join(folder, filename)
    additional_output = File.join(public_folder, "image-max-1000_#{index + 1}.jpg")
    ok = build_max_side(image_tool, additional_source, additional_output, max_side_limit)
    unless ok
      return [false, "Failed to build #{additional_output}"]
    end
  end

  Dir.children(public_folder).each do |filename|
    full_path = File.join(public_folder, filename)
    next unless File.file?(full_path)
    next if expected_outputs.include?(full_path)

    FileUtils.rm_f(full_path)
  end
  [true, nil]
end

FileUtils.mkdir_p(public_root)

product_folders = Dir.children(products_root).sort.select do |entry|
  File.directory?(File.join(products_root, entry))
end

job_count = resolve_job_count(product_folders.length)
puts "Generating product images with #{job_count} job(s)"

queue = Queue.new
product_folders.each { |entry| queue << entry }
errors = []
messages = []
mutex = Mutex.new

workers = Array.new(job_count) do
  Thread.new do
    loop do
      entry = begin
        queue.pop(true)
      rescue ThreadError
        nil
      end
      break unless entry

      ok, message = process_product(
        entry: entry,
        products_root: products_root,
        public_root: public_root,
        target_sizes: target_sizes,
        max_side_output: max_side_output,
        max_side_limit: max_side_limit,
        image_tool: image_tool
      )
      mutex.synchronize do
        if ok
          messages << message if message
        else
          errors << message
        end
      end
    end
  end
end

workers.each(&:join)

messages.sort.each { |message| warn message }

unless errors.empty?
  errors.each { |message| warn message }
  exit 1
end

Dir.children(public_root).each do |entry|
  next if product_folders.include?(entry)

  FileUtils.rm_rf(File.join(public_root, entry))
end
