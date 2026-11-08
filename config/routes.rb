# frozen_string_literal: true

PyriteExtensions::Engine.routes.draw do
  ext_id = PyriteExtensions::Manifest::ID_ROUTE_CONSTRAINT
  version = /[0-9A-Za-z][0-9A-Za-z.\-]*/

  get "/new" => "pages#new", :format => false
  get "/admin" => "pages#admin", :format => false
  get "/manage/:ext_id" => "pages#manage", :format => false, :constraints => { ext_id: }
  get "/install/:ext_id" => "pages#install", :format => false, :constraints => { ext_id: }

  # Plugin ids and versions contain dots, so Rails' implicit ".:format" suffix is disabled.
  scope "/api/v1", defaults: { format: :json } do
    post "/packages" => "packages#create", :format => false
    get "/advisories" => "advisories#index", :format => false
    post "/extensions/:ext_id/versions" => "releases#create", :format => false, :constraints => { ext_id: }
    post "/extensions/:ext_id/moderation" => "moderation#create", :format => false, :constraints => { ext_id: }
    get "/admin/extensions" => "admin/extensions#index", :format => false
    get "/admin/extensions/:ext_id" => "admin/extensions#show", :format => false, :constraints => { ext_id: }
    post "/extensions" => "extensions#create", :format => false
    get "/extensions/:ext_id" => "extensions#show", :format => false, :constraints => { ext_id: }
    get "/extensions/:ext_id/versions/:version" => "releases#show",
        :format => false,
        :constraints => {
          ext_id:,
          version:,
        }
    get "/extensions/:ext_id/versions/:version/package.:package_format" => "downloads#show",
        :format => false,
        :constraints => {
          ext_id:,
          version:,
          package_format: /pyrix|zip/,
        }
  end
end

Discourse::Application.routes.draw { mount ::PyriteExtensions::Engine, at: "/pyrite" }
