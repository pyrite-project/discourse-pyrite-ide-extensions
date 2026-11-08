# frozen_string_literal: true

module PyriteExtensions
  module GuardianExtensions
    # Topics in the registry category are created by the publishing flow so that every one of them
    # has a registry record behind it; staff can still post ordinary announcements.
    def can_create_topic_on_category?(category)
      return super unless registry_category?(category)
      return true if Publishing.active?

      is_staff? && super
    end

    def can_publish_pyrite_extension?
      SiteSetting.pyrite_extensions_enabled && SiteSetting.pyrite_extensions_category.present? &&
        authenticated? &&
        @user.has_trust_level_or_staff?(SiteSetting.pyrite_extensions_min_trust_level_to_publish)
    end

    def can_manage_pyrite_extension?(extension)
      authenticated? && (is_staff? || extension.owner_id == @user.id)
    end

    def can_moderate_pyrite_extensions?
      is_staff?
    end

    # Taken-down packages are visible to staff only; delisted ones also stay visible to their owner.
    def can_see_pyrite_extension?(extension)
      return true if extension.visible_to_public?
      return true if can_moderate_pyrite_extensions?

      can_manage_pyrite_extension?(extension) && !extension.moderation_takedown?
    end

    private

    def registry_category?(category)
      SiteSetting.pyrite_extensions_enabled && category.present? &&
        category.id == SiteSetting.pyrite_extensions_category.to_i
    end
  end
end
