# frozen_string_literal: true

module PyriteExtensions
  # Registry versions are canonical semantic versions without build metadata.
  # Parsing and precedence come from the semantic gem; the canonical check keeps
  # distinct strings such as "01.0.0" or "1.0.0+a" from naming the same release.
  class SemVer
    include Comparable

    attr_reader :version

    def self.parse(text)
      version = Semantic::Version.new(text.to_s)
      new(version) if version.build.nil? && version.to_s == text.to_s
    rescue ArgumentError
      nil
    end

    def initialize(version)
      @version = version
    end

    def <=>(other)
      other.is_a?(SemVer) ? version <=> other.version : nil
    end

    def prerelease?
      !version.pre.nil?
    end

    def to_s
      version.to_s
    end
  end
end
