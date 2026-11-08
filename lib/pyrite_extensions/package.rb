# frozen_string_literal: true

require 'digest'
require 'zip'

module PyriteExtensions
  # Read-only inspection of an uploaded .pyrix/.zip. Nothing is ever extracted on the server:
  # only plugin.toml is read, with a bounded read, so archive bombs cannot expand here.
  class Package
    MANIFEST_ENTRY = 'plugin.toml'
    ENTRY_POINT = '__main__.py'
    MAX_MANIFEST_BYTES = 256 * 1024

    class Rejected < StandardError
    end

    attr_reader :error, :error_detail, :manifest, :sha256, :size

    def self.open(path)
      new(path).tap(&:inspect_archive)
    end

    def initialize(path)
      @path = path
    end

    def valid?
      error.nil?
    end

    def error_message
      I18n.t("pyrite_extensions.package.errors.#{error}", detail: error_detail)
    end

    def inspect_archive
      @size = File.size(@path)
      @sha256 = Digest::SHA256.file(@path).hexdigest
      Zip::File.open(@path) do |archive|
        entries = archive.entries
        reject!(:too_many_entries) if entries.length > SiteSetting.pyrite_extensions_max_package_entries
        entries.each { |entry| check_entry(entry) }
        reject!(:unpacked_too_large) if unpacked_size(entries) > max_unpacked_bytes
        reject!(:entry_point_missing) if archive.find_entry(ENTRY_POINT).nil?
        @manifest = read_manifest(archive)
      end
    rescue Zip::Error, EOFError
      @error ||= :unreadable_archive
    rescue Rejected
      nil
    end

    private

    def check_entry(entry)
      name = entry.name
      unsafe =
        name.start_with?('/', '\\') || name.match?(/\A[A-Za-z]:/) ||
        name.split(%r{[/\\]}).include?('..')
      reject!(:unsafe_entry_path) if unsafe || name.include?("\0")
      reject!(:symlink_entry) if entry.symlink?
    end

    def unpacked_size(entries)
      entries.sum { |entry| entry.size.to_i }
    end

    def max_unpacked_bytes
      SiteSetting.pyrite_extensions_max_unpacked_size_mb.megabytes
    end

    def read_manifest(archive)
      entry = archive.find_entry(MANIFEST_ENTRY) || reject!(:manifest_missing)
      reject!(:manifest_too_large) if entry.size > MAX_MANIFEST_BYTES
      text = entry.get_input_stream { |io| io.read(MAX_MANIFEST_BYTES + 1) }.to_s
      reject!(:manifest_too_large) if text.bytesize > MAX_MANIFEST_BYTES
      text.force_encoding(Encoding::UTF_8)
      reject!(:manifest_syntax, 'the file is not valid UTF-8') unless text.valid_encoding?
      Manifest.from_values(ManifestReader.read(text))
    rescue ManifestReader::Invalid, RangeError => e
      reject!(:manifest_syntax, e.message)
    rescue Manifest::Invalid => e
      reject!(e.reason)
    end

    def reject!(reason, detail = nil)
      @error = reason
      @error_detail = detail
      raise Rejected
    end
  end
end
