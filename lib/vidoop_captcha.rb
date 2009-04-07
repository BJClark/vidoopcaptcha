module Vidoop
  module Captcha
    module Helper

      def vidoop_captcha(options = {})
        image = VidoopCaptcha.request_captcha_image(options)
        return self.build(image)
      end

      def build(image)
        xhtml = Builder::XmlMarkup.new :target => out=('')
        xhtml.div(:class => "captcha") do
          xhtml.label("Captcha", :for => "captcha")
          xhtml.div(:class => "vidoop_secure") do
            xhtml.input(:name => "captcha_id", :value => image.id, :type => :hidden)
            xhtml.input(:type => "text", :id => "captcha", :name => "captcha", :autocomplete => "off", :maxlength => image.length)
          end
          xhtml.script(:type => "text/javascript") do
            xhtml.text! "var vidoop_secure = {  instructions: '"
            xhtml << image.text
            xhtml.text! "' };"
          end
          xhtml.noscript do
            xhtml.image(:src => image.imageURI, :alt => "VidoopSecure Captcha Image")
            xhtml.p(:class => "instructions") do
              xhtml.text! image.text
            end
          end
        end
        return out
      end

    end
  end
end

class VidoopCaptcha
  attr_reader :errors

  class << self
    private :new
    attr_writer :mode

    def build(captcha_id, code)
      case @mode
      when :test_valid
        FakeValidResponse.new
      when :test_invalid
        FakeInvalidResponse.new
      else
        new captcha_id, code
      end
    end

    def load_configuration(config_file)
      if File.exist?(config_file)
        if defined? RAILS_ENV
          vidoopcaptcha = YAML.load_file(config_file)[RAILS_ENV]
        else
          vidoopcaptcha = YAML.load_file(config_file)
        end
        ENV['VIDOOP_SERVER'] = vidoopcaptcha['server']
        ENV['VIDOOP_CUSTOMER_ID'] = vidoopcaptcha['customer_id']
        ENV['VIDOOP_SITE_ID'] = vidoopcaptcha['site_id']
        ENV['VIDOOP_USERNAME'] = vidoopcaptcha['username']
        ENV['VIDOOP_PASSWORD'] = vidoopcaptcha['password']
        @vidoop_config = vidoopcaptcha
      end
    end

  end

  def initialize(captcha_id, code)
    @captcha_id = captcha_id
    @code = code
    @errors = ActiveRecord::Errors.new(self)
  end

  def valid?
    return @valid if instance_variable_defined?(:@valid)
    verify_captcha_response(@captcha_id, @code)
  end

  def self.request_captcha_image(options={})
    @width = options[:width] ||= 3
    @height = options[:height] ||= 3
    minimum_length = (@height*@width).to_i > 11 ? 3 : 4
    if options[:length] && options[:length] < minimum_length
      raise VidoopCaptchaError, "Request parameters did not meet minmum expectations." and return
    end
    @length = options[:length] ||= minimum_length

    @image_code_color = options[:image_code_color] ||= "Blue"
    @image_code_length = options[:image_code_length] ||= 1

    request_url = "https://#{ENV['VIDOOP_SERVER']}/vs/customers/#{ENV['VIDOOP_CUSTOMER_ID']}/sites/#{ENV['VIDOOP_SITE_ID']}/services/captcha"
    options_params = {
      :captcha_length => @length,
      :width => @width,
      :height => @height,
      :image_color_code => @image_code_color,
      :image_code_length => @image_code_length
    }

    response = VidoopCaptcha.post(request_url, options_params, true)
    case response
    when Net::HTTPSuccess

      doc = Hpricot.XML(response.body)
      image = Struct.new("CaptchaImage", :id, :category_names, :captcha_length, :text, :imageURI, :attempted, :authenticated).new

      image.category_names = doc.search("captcha category_names category_name").collect(&:inner_text)
      fields = image.members.dup
      fields.delete_if{|m| m == "category_names"}.each do |mem|
        image.send("#{mem}=", doc.search("captcha #{mem}").inner_text)
      end

      return image

    when Net::HTTPBadRequest
      raise VidoopCaptchaError, "Request parameters did not meet minmum expectations."
    else
      return response.error!
    end

  end

  def verify_captcha_response(captcha_id, code)
    request_url = "https://#{ENV['VIDOOP_SERVER']}/vs/captchas/#{captcha_id}"

    response = VidoopCaptcha.post(request_url, {:code => code})    
    case response
    when Net::HTTPSuccess : true
    when Net::HTTPConflict
      @errors.add_to_base "This captcha has already been attempted, and cannot be attempted again."
      false
    when Net::HTTPGone
      @errors.add_to_base "This captcha has expired."
      false
    when Net::HTTPClientError && response.code == 430
      @errors.add_to_base "The captcha code was entered incorrectly."
      false
    when Net::HTTPNotFound
      @errors.add_to_base "was not found."
      false
    else
      @errors.add_to_base "An unknown error occured with this captcha. Please try again."
      false
    end
  end

  private
  def self.post(request_url, options, auth=false)
    begin
      url = URI.parse(request_url)
      request = Net::HTTP::Post.new(url.path)
      request.basic_auth ENV['VIDOOP_USERNAME'], ENV['VIDOOP_PASSWORD'] if auth
      request.set_form_data(options, '&')

      res = Net::HTTP.new(url.host, url.port)
      res.use_ssl = true
      res = res.start do |http|
        http.request(request)
      end
      return res
    rescue Exception => e
      raise VidoopCaptchaError, e
    end
  end

  class FakeValidResponse
    def valid?; true end
  end

  class FakeInvalidResponse
    def valid?; false end
  end
end
class VidoopCaptchaError < StandardError; end
