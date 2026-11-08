# frozen_string_literal: true

class PyriteExtensions::Extension::Policy::ValidPackage < Service::PolicyBase
  delegate :package, to: :context, private: true

  def call
    package.valid?
  end

  def reason
    package.error_message
  end
end
