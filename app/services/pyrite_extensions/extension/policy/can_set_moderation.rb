# frozen_string_literal: true

class PyriteExtensions::Extension::Policy::CanSetModeration < Service::PolicyBase
  AUTHOR_LEVELS = %w[none deprecated].freeze

  delegate :extension, :release, :params, to: :context, private: true

  def call
    return true if guardian.can_moderate_pyrite_extensions?
    return false if !guardian.can_manage_pyrite_extension?(extension)

    # Authors may deprecate their own work, and withdraw a release soon after
    # publishing it. Anything staff set stays with staff.
    AUTHOR_LEVELS.include?(target.moderation_level) &&
      (AUTHOR_LEVELS.include?(params.level) || author_may_withdraw?)
  end

  def reason
    I18n.t("pyrite_extensions.errors.moderation_not_allowed")
  end

  private

  def target
    release || extension
  end

  def author_may_withdraw?
    params.level == "withdrawn" && release.present? &&
      (release.downloads_count.zero? || release.published_at > withdraw_window.ago)
  end

  def withdraw_window
    SiteSetting.pyrite_extensions_author_withdraw_window_hours.hours
  end
end
