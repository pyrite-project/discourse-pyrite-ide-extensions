# frozen_string_literal: true

module PyriteExtensions
  # Claims outlive every extension in a scope. Never attach dependent cleanup to them.
  class Scope < ActiveRecord::Base
    self.table_name = 'pyrite_extension_scopes'

    belongs_to :owner, class_name: 'User'
    attr_readonly :name, :owner_id

    validates :name, presence: true

    def self.name_for(extension_id)
      extension_id.split('/', 2).first if extension_id&.start_with?('@')
    end

    def self.available_to?(extension_id, user)
      name = name_for(extension_id)
      return true unless name

      owner_id = where(name:).pick(:owner_id)
      owner_id.nil? || owner_id == user.id
    end

    # The unique name index arbitrates concurrent first publications. The caller's
    # publication transaction also rolls back a new claim if publishing fails.
    def self.claim_for(extension_id, owner)
      name = name_for(extension_id)
      return true unless name

      create_or_find_by!(name:) { |scope| scope.owner = owner }.owner_id == owner.id
    end
  end
end
