# frozen_string_literal: true

RSpec.describe PyriteExtensions::ManifestReader do
  describe '.read' do
    it 'reads strings, integers, booleans, and comments' do
      toml = <<~TOML
        # a comment
        name = "Hello \\"World\\" \\u00e9"
        literal = 'raw\\text'
        count = 1_000
        negative = -5
        enabled = true
        disabled = false # trailing comment
      TOML

      expect(described_class.read(toml)).to eq(
        'name' => 'Hello "World" é',
        'literal' => 'raw\\text',
        'count' => 1000,
        'negative' => -5,
        'enabled' => true,
        'disabled' => false
      )
    end

    it 'reads flat and multi-line arrays with comments and trailing commas' do
      toml = <<~TOML
        flat = ["a", "b"]
        empty = []
        multi = [
          "x", # first
          "y",
        ]
      TOML

      expect(described_class.read(toml)).to eq('flat' => %w[a b], 'empty' => [], 'multi' => %w[x y])
    end

    it 'strips a byte order mark and tolerates CRLF line endings' do
      expect(described_class.read("﻿a = 1\r\nb = 2\r\n")).to eq('a' => 1, 'b' => 2)
    end

    it 'stops at the first table header' do
      expect(described_class.read("a = 1\n[tool]\nb = 2\n")).to eq('a' => 1)
    end

    it 'raises for duplicate keys' do
      expect { described_class.read("a = 1\na = 2") }.to raise_error(
        described_class::Invalid,
        /duplicate/
      )
    end

    it 'raises for unterminated strings' do
      expect { described_class.read('a = "oops') }.to raise_error(
        described_class::Invalid,
        /unterminated/
      )
      expect { described_class.read("a = 'oops") }.to raise_error(
        described_class::Invalid,
        /unterminated/
      )
      expect { described_class.read(%(a = "line\nbreak")) }.to raise_error(described_class::Invalid)
    end

    it 'raises for nested arrays' do
      expect { described_class.read('a = [[1], [2]]') }.to raise_error(
        described_class::Invalid,
        /nested/
      )
    end

    it 'raises for unsupported or malformed input' do
      ['a = 1.5', 'a = nope', 'a 1', '= 1', 'a = "x" junk', 'a = [1 2]', 'a = "\\q"'].each do |toml|
        expect { described_class.read(toml) }.to raise_error(described_class::Invalid),
                                                 "expected #{toml} to raise"
      end
    end

    it 'returns an empty hash for blank input' do
      expect(described_class.read('')).to eq({})
      expect(described_class.read(nil)).to eq({})
    end
  end
end
