require "rake"

desc "Generate responsive square image derivatives for products"
task :images do
  sh "ruby scripts/generate_product_images.rb"
end

desc "Generate derivatives then run Jekyll serve"
task :serve do
  sh "bundle exec rake images"
  sh "bundle exec jekyll serve"
end

desc "Generate derivatives then run Jekyll build"
task :build do
  sh "bundle exec rake images"
  sh "bundle exec jekyll build"
end
