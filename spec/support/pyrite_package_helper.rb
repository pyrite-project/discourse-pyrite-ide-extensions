# frozen_string_literal: true

require 'zip'
require 'tmpdir'

module PyritePackageHelper
  VALID_MANIFEST = <<~TOML
    manifest_version = 2
    id = "com.example.hello"
    name = "Hello"
    version = "0.1.0"
    type = "ui"
    protocol_version = 1
    permissions = ["ui.view", "editor.read"]
    platforms = ["windows", "linux", "macos", "android"]
  TOML

  def manifest_toml(overrides = {})
    values = {
      'manifest_version' => 2,
      'id' => 'com.example.hello',
      'name' => 'Hello',
      'version' => '0.1.0',
      'type' => 'ui'
    }.merge(overrides)
    values.map { |key, value| "#{key} = #{value.to_json}" }.join("\n")
  end

  # entries: { "name" => "content" }. Returns the path of the written zip.
  def build_zip(entries = { 'plugin.toml' => VALID_MANIFEST, '__main__.py' => "print('hi')" })
    dir = Dir.mktmpdir('pyrite-spec')
    (@pyrite_tmpdirs ||= []) << dir
    path = File.join(dir, 'package.pyrix')
    Zip::OutputStream.open(path) do |zip|
      entries.each do |name, content|
        zip.put_next_entry(Zip::Entry.new(path, name, time: Zip::DOSTime.at(315_532_800)))
        zip.write(content)
      end
    end
    path
  end

  def uploaded_zip(entries = nil, filename = 'package.pyrix')
    path = entries ? build_zip(entries) : build_zip
    Rack::Test::UploadedFile.new(path, 'application/zip', original_filename: filename)
  end

  def stage_pyrite_upload(owner, entries = nil)
    UploadCreator.new(
      File.open(entries ? build_zip(entries) : build_zip),
      'package.pyrix',
      type: 'pyrite_extension',
      skip_validations: true
    ).create_for(owner.id)
  end

  def cleanup_pyrite_tmpdirs
    (@pyrite_tmpdirs || []).each { |dir| FileUtils.rm_rf(dir) }
  end
end

RSpec.configure do |config|
  config.include PyritePackageHelper
  config.after { cleanup_pyrite_tmpdirs if respond_to?(:cleanup_pyrite_tmpdirs) }
end
