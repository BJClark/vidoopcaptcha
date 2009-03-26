require "vidoop_captcha"
require "hpricot"
require "net/https"

vidoop_config = "#{RAILS_ROOT}/config/vidoop_captcha.yml"
VIDOOP = VidoopCaptcha.load_configuration(vidoop_config)

ActionView::Base.send :include, Vidoop::Captcha::Helper