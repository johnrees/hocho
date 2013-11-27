require 'sinatra'
require 'cgi'
require 'digest/sha1'

class Hocho < Sinatra::Base

  #
  # Resize or crop an image at the given url.
  #
  # The path looks like:
  #   crop/50x50/domain.com/yourimage.jpg
  #
  get '/:recipe/:url/:signature' do |recipe, url, signature|
    # halt 403 unless signature == Digest::SHA1.hexdigest("#{recipe}#{url}#{ENV['SALT']}")
    expires (60 * 60 * 24 * 365), :public
    url = decode(url)

    recipe = recipe ? to_hash(decode(recipe)) : {}
    defaults = { 'o' => 'c', 'd' => 100, 'q' => 80, 'f' => 'jpg' }
    recipe = defaults.merge(recipe)

    # dimensions = sanitize_dimensions(dimensions)
    halt 403 unless url && domain_is_allowed?(url)
    halt 403 unless  %w{ c r t }.include?(recipe['o'])
    image = MiniMagick::Image.open(url)
    send(recipe['o'], image, recipe['d'], recipe['q'], recipe['f'])
    send_file(image.path, :filename => Time.now.to_i.to_s, :type => "image/jpeg", :disposition => "inline")
  end

protected

  #
  # Crop the image
  #
  def c(image, dimensions, quality, format)
    image.combine_options do |command|
      command.filter("box")
      command.resize(dimensions.to_s + "^^")
      command.gravity("Center")
      command.extent(dimensions)
      command.quality quality
    end
    image.format(format)
  end

  #
  # Resize the image
  #
  def r(image, dimensions, quality, format)
    image.combine_options do |command|
      #
      # The box filter majorly decreases processing time without much
      # decrease in quality
      #
      command.filter("box")
      command.resize(dimensions)
      command.quality quality
    end
    image.format(format)
  end

  def t(image, dimensions, quality, format)
    image.combine_options do |command|
      #
      # The box filter majorly decreases processing time without much
      # decrease in quality
      #
      command.filter("box")
      command.resize("#{dimensions}>")
      command.extent(dimensions)
      command.gravity("Center")
      command.quality quality
    end
    image.format(format)
  end

  # #
  # # encode spaces and brackets
  # #
  # def sanitize_url(url)
  #   url.gsub(%r{^https?://}, '').split('/').map {|u| CGI.escape(u) }.join('/')
  # end

  #
  # Fix > chars that get encoded to &gt;
  #
  def sanitize_dimensions(dimensions)
    CGI.unescapeHTML(dimensions)
  end

  #
  # Make sure domain is allowed
  #
  def domain_is_allowed?(url)
    true
  end

private

  def encode string
    string.unpack('H*').first
  end

  def decode hash
    hash.scan(/../).map { |x| x.hex }.pack('c*')
  end

  def to_hash string
    Hash[string.split('&').map{|e| e.split('=')}]
  end

  def to_string hash
    hash.map{|e| e.join('=')}.join('&')
  end

end
