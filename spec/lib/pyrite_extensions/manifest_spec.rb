# frozen_string_literal: true

RSpec.describe PyriteExtensions::Manifest do
  let(:values) do
    {
      'manifest_version' => 2,
      'id' => 'com.example.hello',
      'name' => 'Hello',
      'version' => '0.1.0',
      'type' => 'ui',
      'permissions' => %w[ui.view],
      'platforms' => %w[windows linux],
      'author' => 'Ann'
    }
  end

  describe '.from_values' do
    it 'builds a manifest from valid values' do
      manifest = described_class.from_values(values)

      expect(manifest.to_h).to include(
        'id' => 'com.example.hello',
        'version' => '0.1.0',
        'platforms' => %w[windows linux],
        'author' => 'Ann'
      )
      expect(manifest.semver).to eq(PyriteExtensions::SemVer.parse('0.1.0'))
    end

    it 'defaults manifest_version, platforms, and permissions' do
      manifest =
        described_class.from_values(values.except('manifest_version', 'platforms', 'permissions'))

      expect(manifest.manifest_version).to eq(1)
      expect(manifest.platforms).to eq(described_class::PLATFORMS)
      expect(manifest.permissions).to eq([])
    end

    {
      id: [
        { 'id' => 'Com.Example' },
        { 'id' => 'bad id' },
        { 'id' => nil },
        { 'id' => 'a' * 215 },
        { 'id' => '@scope' },
        { 'id' => '@/name' },
        { 'id' => 'scope/name' },
        { 'id' => '@Scope/name' },
        { 'id' => '@scope/' },
        { 'id' => '@scope/a/b' },
        { 'id' => '.hidden' },
        { 'id' => '_private' },
        { 'id' => 'trailing.' },
        { 'id' => 'con' },
        { 'id' => '@scope/aux.txt' }
      ],
      name: [{ 'name' => '' }, { 'name' => '   ' }, { 'name' => 5 }, { 'name' => 'a' * 101 }],
      version: [{ 'version' => '1.0' }, { 'version' => '01.0.0' }, { 'version' => nil }],
      type: [{ 'type' => 'widget' }, { 'type' => nil }],
      manifest_version: [{ 'manifest_version' => 3 }, { 'manifest_version' => '2' }],
      platforms: [{ 'platforms' => [] }, { 'platforms' => %w[beos] }, { 'platforms' => 'windows' }],
      permissions: [
        { 'permissions' => 'ui.view' },
        { 'permissions' => [1] },
        { 'permissions' => ['a' * 65] }
      ]
    }.each do |field, overrides|
      it "raises manifest_invalid_#{field} for an invalid #{field}" do
        overrides.each do |override|
          expect { described_class.from_values(values.merge(override)) }.to raise_error(
            described_class::Invalid
          ) { |error|
            expect(error.reason).to eq(:"manifest_invalid_#{field}"), "#{override}: #{error.reason}"
          }
        end
      end
    end
  end
end
