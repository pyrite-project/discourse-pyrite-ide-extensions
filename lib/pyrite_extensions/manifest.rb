# frozen_string_literal: true

module PyriteExtensions
  # The slice of plugin.toml the registry stores and publishes. Field rules mirror the IDE
  # (lib/core/sdk/plugin_manifest.dart); the id is stricter so ids cannot collide by case.
  class Manifest
    class Invalid < StandardError
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason.to_s)
      end
    end

    # npm package names: a bare name or @scope/name, lowercase, URL and file-name safe.
    # Names must start and end with a letter or digit so they map to a valid
    # directory name on every platform (Windows drops trailing dots).
    NAME_PART = "[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?"
    ID_BODY = "(?:@#{NAME_PART}/)?#{NAME_PART}"
    ID_PATTERN = /\A#{ID_BODY}\z/
    # Clients that follow npm's conventions send the scope separator as %2F.
    ID_ROUTE_CONSTRAINT = %r{(?:@#{NAME_PART}(?:/|%2[Ff]))?#{NAME_PART}}
    MAX_ID_LENGTH = 214
    WINDOWS_RESERVED = /\A(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|\z)/

    def self.valid_id?(id)
      id.is_a?(String) && id.length <= MAX_ID_LENGTH && id.match?(ID_PATTERN) &&
        id.delete_prefix("@").split("/").none? { |part| part.match?(WINDOWS_RESERVED) }
    end

    MAX_NAME_LENGTH = 100
    MAX_PERMISSION_LENGTH = 64
    TYPES = %w[ui service data].freeze
    MANIFEST_VERSIONS = [1, 2].freeze
    PLATFORMS = %w[windows linux macos android].freeze

    attr_reader :id,
                :name,
                :version,
                :type,
                :manifest_version,
                :platforms,
                :permissions,
                :author,
                :description

    def self.from_values(values)
      new(values).tap(&:validate!)
    end

    def initialize(values)
      @id = values['id']
      @name = values['name']
      @version = values['version']
      @type = values['type']
      @manifest_version = values['manifest_version'] || 1
      @platforms = values['platforms'] || PLATFORMS
      @permissions = values['permissions'] || []
      @author = values['author']
      @description = values['description']
    end

    def semver
      SemVer.parse(version)
    end

    def to_h
      {
        'id' => id,
        'name' => name,
        'version' => version,
        'type' => type,
        'manifest_version' => manifest_version,
        'platforms' => platforms,
        'permissions' => permissions,
        'author' => author,
        'description' => description
      }
    end

    def validate!
      invalid!(:id) unless self.class.valid_id?(id)
      invalid!(:name) unless name.is_a?(String) && name.strip.present? && name.length <= MAX_NAME_LENGTH
      invalid!(:version) unless semver
      invalid!(:type) if TYPES.exclude?(type)
      invalid!(:manifest_version) if MANIFEST_VERSIONS.exclude?(manifest_version)
      invalid!(:platforms) unless known_platforms?
      invalid!(:permissions) unless short_strings?(permissions)
    end

    private

    def known_platforms?
      platforms.is_a?(Array) && platforms.any? && (platforms - PLATFORMS).empty?
    end

    def short_strings?(list)
      list.is_a?(Array) &&
        list.all? { |item| item.is_a?(String) && item.length <= MAX_PERMISSION_LENGTH }
    end

    def invalid!(field)
      raise Invalid, :"manifest_invalid_#{field}"
    end
  end
end
