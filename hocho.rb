require 'sinatra'
require 'cgi'

class Hocho < Sinatra::Base

  #
  # Resize or crop an image at the given url.
  #
  # The path looks like:
  #   crop/50x50/domain.com/yourimage.jpg
  #
  get '/:operation,:quality,:dimensions,:format/*' do |operation, quality, dimensions, format, url|
    expires (60 * 60 * 24 * 365), :public
    # cache_control :public, max_age: 60 * 60 * 24 * 365
    url = sanitize_url(url)

    dimensions = sanitize_dimensions(dimensions)

    halt 403 unless url && domain_is_allowed?(url)
    halt 403 unless  %w{ crop resize }.include?(operation)
    image = MiniMagick::Image.open("http://#{ url }")
    send(operation, image, dimensions, quality, format)
    send_file(image.path, :filename => Time.now.to_i.to_s, :type => "image/jpeg", :disposition => "inline")
  end

  protected

  #
  # Crop the image
  #
  def crop(image, dimensions, quality, format)
    image.combine_options do |command|
      command.filter("box")
      command.resize(dimensions + "^^")
      command.gravity("Center")
      command.extent(dimensions)
      command.quality quality
    end
    image.format(format)
  end

  #
  # Resize the image
  #
  def resize(image, dimensions, quality, format)
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

  #
  # encode spaces and brackets
  #
  def sanitize_url(url)
    url.gsub(%r{^https?://}, '').split('/').map {|u| CGI.escape(u) }.join('/')
  end

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

end
