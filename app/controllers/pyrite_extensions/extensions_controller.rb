# frozen_string_literal: true

module PyriteExtensions
  class ExtensionsController < BaseController
    before_action :ensure_logged_in, only: :create
    before_action :rate_limit_publishing, only: :create

    def show
      extension = find_visible_extension!
      serializer =
        guardian.can_manage_pyrite_extension?(extension) ? ManageExtensionSerializer : ExtensionSerializer
      render_serialized(extension, serializer, root: "extension")
    end

    def create
      Extension::Publish.call(service_params) do
        on_success do |extension:|
          render_serialized(extension, ExtensionSerializer, root: "extension")
        end
        on_failed_policy(:can_publish) { raise Discourse::InvalidAccess }
        on_failed_policy(:valid_package) { |policy| render_json_error(policy.reason, status: 422) }
        on_failed_contract do |contract|
          render_json_error(contract.errors.full_messages, status: 400)
        end
        on_model_not_found(:upload) { raise Discourse::NotFound }
        on_model_not_found(:package) { raise Discourse::NotFound }
        on_model_not_found(:topic) do |topic_result|
          render_json_error(
            topic_result.exception&.message || I18n.t('pyrite_extensions.errors.topic_failed'),
            status: 422
          )
        end
        on_model_errors(:extension) { |extension| render_json_error(extension, status: 422) }
        on_model_errors(:release) { |release| render_json_error(release, status: 422) }
        on_exceptions { |exception| render_json_error(exception.message, status: 422) }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    private

    def rate_limit_publishing
      RateLimiter.new(current_user, 'pyrite-extension-publish', 10, 1.hour).performed!
    end
  end
end
