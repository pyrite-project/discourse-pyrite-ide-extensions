# frozen_string_literal: true

RSpec.describe PyriteExtensions::SemVer do
  describe '.parse' do
    it 'parses core versions and pre-release identifiers' do
      version = described_class.parse('1.2.3-alpha.1')

      expect([version.version.major, version.version.minor, version.version.patch]).to eq([1, 2, 3])
      expect(version.version.pre).to eq('alpha.1')
      expect(version.to_s).to eq('1.2.3-alpha.1')
      expect(version).to be_prerelease
      expect(described_class.parse('1.2.3')).not_to be_prerelease
    end

    it 'rejects leading zeros, build metadata, and malformed input' do
      %w[
        01.2.3
        1.02.3
        1.2.03
        1.2.3-01
        1.2.3+build
        1.2.3-rc.1+build
        1.2
        v1.2.3
        1.2.3-
      ].each do |text|
        expect(described_class.parse(text)).to be_nil, "expected #{text} to be rejected"
      end
      expect(described_class.parse(nil)).to be_nil
    end
  end

  describe '#<=>' do
    it 'orders according to the semver spec' do
      ordered = %w[
        1.0.0-alpha
        1.0.0-alpha.1
        1.0.0-alpha.beta
        1.0.0-beta
        1.0.0-beta.2
        1.0.0-beta.11
        1.0.0-rc.1
        1.0.0
        1.0.1
        1.1.0
        2.0.0
      ]

      parsed = ordered.map { |text| described_class.parse(text) }

      expect(parsed.shuffle(random: Random.new(1)).sort.map(&:to_s)).to eq(ordered)
    end

    it 'compares numerically rather than lexically and is nil for other types' do
      expect(described_class.parse('1.10.0')).to be > described_class.parse('1.9.0')
      expect(described_class.parse('1.0.0')).to eq(described_class.parse('1.0.0'))
      expect(described_class.parse('1.0.0') <=> '1.0.0').to be_nil
    end
  end
end
