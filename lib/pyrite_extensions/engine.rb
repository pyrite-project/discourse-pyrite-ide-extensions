# frozen_string_literal: true

module ::PyriteExtensions
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace PyriteExtensions
  end
end
