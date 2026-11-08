# frozen_string_literal: true

require_relative '../../support/pyrite_package_helper'

RSpec.describe PyriteExtensions::Package do
  def open_package(path = build_zip)
    described_class.open(path)
  end

  describe '.open' do
    it 'reads a valid package' do
      path = build_zip
      package = open_package(path)

      expect(package).to be_valid
      expect(package.manifest.id).to eq('com.example.hello')
      expect(package.manifest.permissions).to eq(%w[ui.view editor.read])
      expect(package.sha256).to eq(Digest::SHA256.file(path).hexdigest)
      expect(package.size).to eq(File.size(path))
    end

    it 'rejects a package without plugin.toml' do
      package = open_package(build_zip('__main__.py' => 'x'))

      expect(package.error).to eq(:manifest_missing)
      expect(package.error_message).to eq(
        I18n.t('pyrite_extensions.package.errors.manifest_missing')
      )
    end

    it 'rejects a package without __main__.py' do
      package = open_package(build_zip('plugin.toml' => PyritePackageHelper::VALID_MANIFEST))

      expect(package.error).to eq(:entry_point_missing)
    end

    it 'rejects entries that escape the package folder' do
      ['../evil.py', 'a/../../evil.py', 'a\\..\\evil.py'].each do |name|
        package =
          open_package(
            build_zip(
              'plugin.toml' => PyritePackageHelper::VALID_MANIFEST,
              '__main__.py' => 'x',
              name => 'x'
            )
          )

        expect(package.error).to eq(:unsafe_entry_path), "expected #{name} to be unsafe"
      end
    end

    it 'rejects a manifest that is too large' do
      big =
        PyritePackageHelper::VALID_MANIFEST +
        "# #{'a' * (described_class::MAX_MANIFEST_BYTES + 10)}\n"
      package = open_package(build_zip('plugin.toml' => big, '__main__.py' => 'x'))

      expect(package.error).to eq(:manifest_too_large)
    end

    it 'rejects a manifest that is not valid UTF-8' do
      bad = PyritePackageHelper::VALID_MANIFEST.b + "\xFF\xFE".b
      package = open_package(build_zip('plugin.toml' => bad, '__main__.py' => 'x'))

      expect(package.error).to eq(:manifest_syntax)
      expect(package.error_message).to include('UTF-8')
    end

    it 'rejects a manifest with a syntax error' do
      package = open_package(build_zip('plugin.toml' => 'id = ', '__main__.py' => 'x'))

      expect(package.error).to eq(:manifest_syntax)
    end

    it 'reports the manifest field that is invalid' do
      package =
        open_package(
          build_zip('plugin.toml' => manifest_toml('type' => 'widget'), '__main__.py' => 'x')
        )

      expect(package.error).to eq(:manifest_invalid_type)
    end

    it 'rejects a file that is not a zip' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'garbage.pyrix')
      File.write(path, 'this is not a zip')

      expect(open_package(path).error).to eq(:unreadable_archive)
    ensure
      FileUtils.rm_rf(dir)
    end

    it 'rejects a package with too many entries' do
      SiteSetting.pyrite_extensions_max_package_entries = 10
      entries = { 'plugin.toml' => PyritePackageHelper::VALID_MANIFEST, '__main__.py' => 'x' }
      10.times { |index| entries["f#{index}.txt"] = 'x' }

      expect(open_package(build_zip(entries)).error).to eq(:too_many_entries)
    end

    it 'rejects a package whose unpacked size is too large' do
      SiteSetting.pyrite_extensions_max_unpacked_size_mb = 1
      package =
        open_package(
          build_zip(
            'plugin.toml' => PyritePackageHelper::VALID_MANIFEST,
            '__main__.py' => 'a' * 2.megabytes
          )
        )

      expect(package.error).to eq(:unpacked_too_large)
    end
  end
end
