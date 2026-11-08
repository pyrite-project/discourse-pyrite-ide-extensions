# frozen_string_literal: true

module PyriteExtensions
  # Audit trail for every moderation change; the current state itself lives on the moderated record.
  class ModerationEvent < ActiveRecord::Base
    self.table_name = 'pyrite_extension_moderation_events'

    belongs_to :extension, class_name: 'PyriteExtensions::Extension'
    belongs_to :release, class_name: 'PyriteExtensions::Release', optional: true
    belongs_to :actor, class_name: 'User'

    enum :level, Moderatable::LEVELS, prefix: true
  end
end
