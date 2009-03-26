require File.dirname(__FILE__) + '/spec_helper'

class TestController < ApplicationController;end

module Vidoop::Captcha

  describe Helper do
    before(:each) do
      @klass = Class.new {include Helper}
      @captcha = @klass.new
      @image = Struct.new("CaptchaImage", :id, :category_names, :captcha_length, :text, :imageURI, :attempted, :authenticated).
      new("cpt123", ["foo", "bar"], 2, "foo bar", "http://api.vidoop.com/vs/captchas/cpt123/image", false, false)
    end

    describe "rendering a catpcha" do

      it "should build xhtml form pieces" do
        VidoopCaptcha.should_receive(:request_captcha_image).and_return @image
        @captcha.vidoop_captcha().should have_tag "div.captcha" do
          with_tag "image", :src => "http://api.vidoop.com/vs/captchas/cpt123/image"
          with_tag "input[name=captcha_id][type=hidden]"
          with_tag "input[name=captcha][type=text]"
        end
      end

    end
  end

end

describe VidoopCaptcha do

  context "requesting an image" do
    before do
      @image = Struct.new("CaptchaImage", :id, :category_names, :captcha_length, :text, :imageURI, :attempted, :authenticated).
      new("cpt123", ["foo", "bar"], 2, "foo bar", "http://api.vidoop.com/vs/captchas/cpt123/image", false, false)
    end
    it "should verify a 9 image grid has 4 categories" do
      lambda {VidoopCaptcha.request_captcha_image(:height => 3, :width => 3, :length => 3)}.should raise_error(VidoopCaptchaError)
    end

    it "should verify a 12 image grid has atleast 3 categories" do
      VidoopCaptcha.stub!(:request_captcha_image).and_return @image
      lambda {VidoopCaptcha.request_captcha_image(:height => 4, :width => 3, :length => 3)}.should_not raise_error(VidoopCaptchaError)
    end

    it "should return a Struct representing the xml returned by Vidoop" do
      xml = <<-xml
      <captcha uri="https://api.vidoop.com/vs/captchas/NVBRFYB44N">
      <category_names>
      <category_name>wild animals</category_name>
      <category_name>computers</category_name>
      <category_name>food</category_name>
      </category_names>
      <text>Enter the letters, in order, for: wild animals, computers, food</text>
      <id>NVBRFYB44N</id>
      <captcha_length>3</captcha_length>
      <order_matters>True</order_matters>
      <width>3</width>
      <height>4</height>
      <image_code_color>Red</image_code_color>
      <image_code_length>1</image_code_length>
      <imageURI>https://api.vidoop.com/vs/captchas/NVBRFYB44N/image</imageURI>
      <attempted>false</attempted>
      <authenticated>false</authenticated>
      </captcha>
      xml
      response = Net::HTTPSuccess.new("1.1", "200", "Success")
      response.stub!(:body).and_return(xml)
      VidoopCaptcha.stub!(:post).and_return response
      struct = Struct.new("CaptchaImage", :id, :category_names, :captcha_length, :text, :imageURI, :attempted, :authenticated).
      new("NVBRFYB44N", ["wild animals", "computers", "food"], "3", "Enter the letters, in order, for: wild animals, computers, food", "https://api.vidoop.com/vs/captchas/NVBRFYB44N/image", "false", "false")
      VidoopCaptcha.request_captcha_image.to_yaml.should == struct.to_yaml
    end

  end


  context "verifing entered code" do
    it "should validate a users response" do
      VidoopCaptcha.mode = :test_valid
      @captcha = VidoopCaptcha.build("cpt123", "abc")
      @captcha.should be_valid
    end

    it "should return invalid" do
      VidoopCaptcha.mode = :test_invalid
      @captcha = VidoopCaptcha.build("cpt123", "abc")
      @captcha.should_not be_valid
    end

    it "should verify code with server" do
      VidoopCaptcha.mode = :do_it_for_real
      VidoopCaptcha.should_receive(:post).
      with("https://api.vidoop.com/vs/captcha/cpt123", {:code => "abc"}, false).
      and_return(Net::HTTPResponse.new("1.1", 430, "Unauthorized" ))
      @captcha = VidoopCaptcha.build("cpt123", "abc")
      @captcha.should_not be_valid
      @captcha.errors.should_not be_blank
    end
  end

end
