# frozen_string_literal: true

require "optparse"
require "json"

module HamExamParser
  class CLI
    def initialize(argv)
      @options = parse_options(argv)
    end

    def run
      validate_options!

      parser = DocxParser.new(@options[:input])
      parser.parse

      if @options[:images]
        encoder = ImageEncoder.new(@options[:images])
        parser.attach_images(encoder)
      end

      result = parser.to_structured_hash(
        exam_class: @options[:exam_class],
        pool_year: @options[:pool_year]
      )

      json = if @options[:pretty]
               JSON.pretty_generate(result)
             else
               JSON.generate(result)
             end

      if @options[:output]
        File.write(@options[:output], json)
        $stderr.puts "Wrote #{parser.questions.size} questions to #{@options[:output]}"
      else
        puts json
      end
    end

    private

    def parse_options(argv)
      options = { pretty: false }

      OptionParser.new do |opts|
        opts.banner = "Usage: parse_pool [options]"

        opts.on("-i", "--input FILE", "Path to .docx question pool file (required)") do |f|
          options[:input] = f
        end

        opts.on("--images DIR", "Path to directory of figure images") do |d|
          options[:images] = d
        end

        opts.on("-o", "--output FILE", "Output JSON file (default: stdout)") do |f|
          options[:output] = f
        end

        opts.on("-p", "--pretty", "Pretty-print JSON output") do
          options[:pretty] = true
        end

        opts.on("--exam-class CLASS", "Exam class (technician, general, extra)") do |c|
          options[:exam_class] = c
        end

        opts.on("--pool-year YEAR", "Pool year range (e.g., 2022-2026)") do |y|
          options[:pool_year] = y
        end

        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit
        end
      end.parse!(argv)

      options
    end

    def validate_options!
      unless @options[:input]
        $stderr.puts "Error: --input FILE is required"
        exit 1
      end

      unless File.exist?(@options[:input])
        $stderr.puts "Error: Input file not found: #{@options[:input]}"
        exit 1
      end
    end
  end
end
