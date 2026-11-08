# frozen_string_literal: true

module PyriteExtensions
  class PackagesController < BaseController
    before_action :ensure_logged_in
    before_action :rate_limit_uploads

    def create
      Extension::UploadPackage.call(service_params) do
        on_success do |upload:, package:, extension: nil|
          render_serialized(upload, StagedPackageSerializer, root: "package", package:, extension:)
        end
        on_failed_policy(:can_publish) { raise Discourse::InvalidAccess }
        on_failed_policy(:scope_available) do
          render_json_error(I18n.t("pyrite_extensions.errors.scope_taken"), status: 403)
        end
        on_failed_policy(:valid_package) { |policy| render_json_error(policy.reason, status: 422) }
        on_failed_policy(:extension_id_available) do
          render_json_error(I18n.t("pyrite_extensions.errors.ext_id_taken"), status: 403)
        end
        on_failed_policy(:version_not_published) do
          render_json_error(I18n.t("pyrite_extensions.errors.version_exists"), status: 409)
        end
        on_failed_contract do |contract|
          render_json_error(contract.errors.full_messages, status: 400)
        end
        on_model_errors(:upload) { |upload| render_json_error(upload, status: 422) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def rate_limit_uploads
      RateLimiter.new(current_user, "pyrite-package-upload", 20, 1.hour).performed!
    end
  end
end
