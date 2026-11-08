# frozen_string_literal: true

module PyriteExtensions
  class ReleasesController < BaseController
    before_action :ensure_logged_in, only: :create
    before_action :rate_limit_publishing, only: :create

    def show
      extension = find_visible_extension!
      render_serialized(find_visible_release!(extension), ReleaseSerializer, root: false)
    end

    def create
      Extension::PublishRelease.call(service_params) do
        on_success { |release:| render json: success_json.merge(version: release.version) }
        on_failed_contract { |contract| render_json_error(contract.errors.full_messages, status: 400) }
        on_model_not_found(:extension) { raise Discourse::NotFound }
        on_model_not_found(:upload) { raise Discourse::NotFound }
        on_model_not_found(:package) { raise Discourse::NotFound }
        # Someone who cannot see the plugin must not learn that it exists.
        on_failed_policy(:can_manage) do |_policy, extension:|
          raise(guardian.can_see_pyrite_extension?(extension) ? Discourse::InvalidAccess : Discourse::NotFound)
        end
        on_failed_policy(:extension_not_removed) { raise Discourse::NotFound }
        on_failed_policy(:valid_package) { |policy| render_json_error(policy.reason, status: 422) }
        on_failed_policy(:package_belongs_to_extension) { |policy| render_json_error(policy.reason, status: 422) }
        on_failed_policy(:version_not_published) do
          render_json_error(I18n.t("pyrite_extensions.errors.version_exists"), status: 409)
        end
        on_model_errors(:release) { |release| render_json_error(release, status: 422) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def rate_limit_publishing
      RateLimiter.new(current_user, "pyrite-extension-publish", 10, 1.hour).performed!
    end
  end
end
