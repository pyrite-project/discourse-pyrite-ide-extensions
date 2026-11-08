# frozen_string_literal: true

PyriteExtensions::Engine.routes.draw do
  ext_id = PyriteExtensions::Manifest::ID_ROUTE_CONSTRAINT
  version = /[0-9A-Za-z][0-9A-Za-z.\-]*/

  get "/new" => "pages#new", :format => false
  get "/manage/:ext_id" => "pages#manage", :format => false, :constraints => { ext_id: }
  get "/install/:ext_id" => "pages#install", :format => false, :constraints => { ext_id: }

  # Match the JSON suffix literally: IDs and semantic versions also contain dots.
  scope "/registry", defaults: { format: :json } do
    post "/packages.json" => "packages#create", :format => false
    get "/advisories.json" => "advisories#index", :format => false
    post "/extensions/:ext_id/releases.json" => "releases#create", :format => false, :constraints => { ext_id: }
    post "/extensions/:ext_id/moderation.json" => "moderation#create", :format => false, :constraints => { ext_id: }
    get "/admin/extensions.json" => "admin/extensions#index", :format => false
    get "/admin/extensions/:ext_id.json" => "admin/extensions#show", :format => false, :constraints => { ext_id: }
    post "/extensions.json" => "extensions#create", :format => false
    get "/extensions/:ext_id.json" => "extensions#show", :format => false, :constraints => { ext_id: }
    get "/extensions/:ext_id/releases.json" => "releases#index",
        :format => false, :constraints => { ext_id: }
    get "/extensions/:ext_id/releases/:version.json" => "releases#show",
        :format => false,
        :constraints => {
          ext_id:,
          version:,
        }
    get "/extensions/:ext_id/releases/:version/package.:package_format" => "downloads#show",
        :format => false,
        :constraints => {
          ext_id:,
          version:,
          package_format: /pyrix|zip/,
        }
  end
end

Discourse::Application.routes.draw do
  mount ::PyriteExtensions::Engine, at: "/pyrite"

  get "/admin/plugins/discourse-pyrite-ide-extensions/registry" =>
        "pyrite_extensions/pages#admin", :constraints => StaffConstraint.new
end
