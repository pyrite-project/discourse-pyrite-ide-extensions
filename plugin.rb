# frozen_string_literal: true

# name: discourse-pyrite-ide-extensions
# about: Plugin registry for Pyrite IDE extensions.
# version: 0.1.0
# authors: kainordherd
# url: https://github.com/pyrite-project/discourse-pyrite-ide-extensions

enabled_site_setting :pyrite_extensions_enabled
add_admin_route "pyrite_extensions.admin.title",
                "discourse-pyrite-ide-extensions",
                use_new_show_route: true
register_svg_icon "puzzle-piece"

gem 'semantic', '1.6.1'

register_asset 'stylesheets/pyrite-extensions.scss'

module ::PyriteExtensions
  PLUGIN_NAME = 'discourse-pyrite-ide-extensions'
end

require_relative 'lib/pyrite_extensions/engine'
require_relative 'lib/pyrite_extensions/sem_ver'
require_relative 'lib/pyrite_extensions/manifest_reader'
require_relative 'lib/pyrite_extensions/manifest'
require_relative 'lib/pyrite_extensions/package'
require_relative 'lib/pyrite_extensions/managed_block'
require_relative 'lib/pyrite_extensions/publishing'

after_initialize do
  require_relative 'lib/pyrite_extensions/guardian_extensions'

  reloadable_patch { Guardian.prepend(PyriteExtensions::GuardianExtensions) }
end
