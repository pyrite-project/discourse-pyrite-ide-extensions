# frozen_string_literal: true

module PyriteExtensions
  # The IDE asks, for the releases it has installed, whether anything changed
  # since they were installed. Unflagged releases are answered too, so a warning
  # that was lifted can be cleared.
  class AdvisoriesController < BaseController
    MAX_RELEASES = 100

    before_action :rate_limit_checks

    def index
      releases = requested_releases
      return render_json_error(I18n.t("pyrite_extensions.errors.too_many_releases"), status: 400) if releases.nil?

      render_serialized(find_releases(releases), AdvisorySerializer, root: "advisories")
    end

    private

    # "@scope/name@1.2.0,other@2.0.0": the version follows the last "@", because
    # a scoped id starts with one.
    def requested_releases
      pairs =
        params[:releases].to_s.split(",").filter_map do |entry|
          id, separator, version = entry.rpartition("@")
          [id, version] if separator.present? && id.present? && version.present?
        end.uniq
      pairs if pairs.length <= MAX_RELEASES
    end

    def find_releases(pairs)
      extensions = Extension.includes(:releases).where(ext_id: pairs.map(&:first).uniq).index_by(&:ext_id)
      pairs.filter_map do |id, version|
        extensions[id]&.releases&.find { |release| release.version == version }
      end
    end

    def rate_limit_checks
      RateLimiter.new(nil, "pyrite-advisories-#{request.remote_ip}", 60, 1.hour).performed!
    end
  end
end
