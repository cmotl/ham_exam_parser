# frozen_string_literal: true

require "base64"
require "tempfile"

module HamExamParser
  class ImageEncoder
    SUPPORTED_EXTENSIONS = %w[.png .jpg .jpeg .gif .bmp .svg].freeze

    def initialize(image_dir)
      @image_dir = image_dir
      @image_map = build_image_map
    end

    def encode(figure_ref)
      return nil unless figure_ref

      path = @image_map[normalize_ref(figure_ref)]
      return nil unless path && File.exist?(path)

      image_data = if File.extname(path).downcase == ".svg"
                     convert_svg_to_jpg(path)
                   else
                     File.binread(path)
                   end

      return nil unless image_data

      Base64.strict_encode64(image_data)
    end

    private

    def convert_svg_to_jpg(svg_path)
      tmpfile = Tempfile.new(["figure", ".jpg"])
      tmpfile.close

      # Try rsvg-convert first, fall back to ImageMagick convert
      success = system("rsvg-convert", "-f", "png", "-o", tmpfile.path, svg_path) ||
                system("convert", svg_path, tmpfile.path)

      unless success
        $stderr.puts "Warning: Could not convert SVG #{svg_path} — install rsvg-convert or ImageMagick"
        return nil
      end

      File.binread(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    def build_image_map
      return {} unless @image_dir && Dir.exist?(@image_dir)

      map = {}
      Dir.glob(File.join(@image_dir, "*")).each do |path|
        ext = File.extname(path).downcase
        next unless SUPPORTED_EXTENSIONS.include?(ext)

        basename = File.basename(path, ext)
        map[normalize_ref(basename)] = path
      end
      map
    end

    def normalize_ref(ref)
      ref.to_s.strip.downcase.gsub(/[\s_\-]+/, "")
    end
  end
end
