require 'ftools'

if File.directory? "config"
  dest_dir = "config"
  src_config_file = File.join(File.dirname(__FILE__),"vidoop_captcha.yml")
  dest_config_file = File.join(dest_dir, "vidoop_captcha.yml") if dest_dir

  if File::exists? dest_config_file
    STDERR.puts "\nA config file already exists at #{dest_config_file}.\n"
  else
    File.copy src_config_file, dest_config_file
  end

else
  STDERR.puts "\nA config file already exists at #{dest_config_file}.\n"
end

if File.directory? "public/javascripts"
  dest_dir = "public/javascripts"
  src_js_file = File.join(File.dirname(__FILE__),"flyout.min.js")
  dest_js_file = File.join(dest_dir, "flyout.min.js") if dest_dir

  if File::exists? dest_js_file
    STDERR.puts "\nA js file already exists at #{dest_js_file}.\n"
  else
    File.copy src_js_file, dest_js_file
  end
else
  STDERR.puts "\nA js file already exists at #{dest_js_file}.\n"
end
