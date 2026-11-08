# frozen_string_literal: true

require 'strscan'

module PyriteExtensions
  # Reads the top-level keys of a plugin.toml (everything before the first table header),
  # which is all the registry needs. Strings, integers, booleans and flat arrays are supported.
  class ManifestReader
    class Invalid < StandardError
    end

    KEY = /[A-Za-z0-9_-]+/
    ESCAPES = {
      'b' => "\b",
      't' => "\t",
      'n' => "\n",
      'f' => "\f",
      'r' => "\r",
      '"' => '"',
      '\\' => '\\'
    }.freeze

    def self.read(text)
      new(text).read
    end

    def initialize(text)
      @scanner = StringScanner.new(text.to_s.delete_prefix('﻿'))
    end

    def read
      values = {}
      loop do
        skip_blank
        break if @scanner.eos? || @scanner.check(/\[/)

        key = @scanner.scan(KEY) || invalid('a key was expected')
        invalid("duplicate key #{key}") if values.key?(key)
        @scanner.skip(/[ \t]*=[ \t]*/) || invalid("'=' was expected after #{key}")
        values[key] = read_value
        @scanner.skip(/[ \t]*(?:#[^\n]*)?(?:\r?\n|\z)/) || invalid("unexpected text after #{key}")
      end
      values
    end

    private

    def read_value
      if @scanner.skip(/"/)
        read_basic_string
      elsif @scanner.skip(/'/)
        @scanner.scan(/[^'\n]*/).tap { @scanner.skip(/'/) || invalid('unterminated string') }
      elsif @scanner.skip(/\[/)
        read_array
      elsif @scanner.scan(/true(?![\w-])/)
        true
      elsif @scanner.scan(/false(?![\w-])/)
        false
      elsif (number = @scanner.scan(/[+-]?\d[\d_]*(?![\w.])/))
        Integer(number.delete('_'), 10)
      else
        invalid('unsupported value')
      end
    end

    def read_basic_string
      text = +''
      loop do
        text << @scanner.scan(/[^"\\\n]*/)
        if @scanner.skip(/"/)
          return text
        elsif @scanner.skip(/\\u(\h{4})/)
          text << @scanner[1].hex.chr(Encoding::UTF_8)
        elsif @scanner.skip(/\\(.)/)
          text << (ESCAPES[@scanner[1]] || invalid('unknown escape'))
        else
          invalid('unterminated string')
        end
      end
    end

    def read_array
      items = []
      loop do
        skip_blank
        return items if @scanner.skip(/\]/)

        item = read_value
        invalid('nested arrays are not supported') if item.is_a?(Array)
        items << item
        skip_blank
        next if @scanner.skip(/,/)

        @scanner.skip(/\]/) ? (return items) : invalid("']' was expected")
      end
    end

    def skip_blank
      @scanner.skip(/(?:\s|#[^\n]*)+/)
    end

    def invalid(detail)
      raise Invalid, detail
    end
  end
end
