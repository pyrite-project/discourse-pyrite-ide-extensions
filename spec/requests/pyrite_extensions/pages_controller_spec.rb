# frozen_string_literal: true

RSpec.describe PyriteExtensions::PagesController do
  fab!(:category)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:newcomer) { Fabricate(:user, trust_level: TrustLevel[0]) }

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  describe "#admin" do
    fab!(:moderator)

    it "serves the registry inside the admin route for moderators" do
      sign_in(moderator)

      get "/admin/plugins/discourse-pyrite-ide-extensions/registry"

      expect(response.status).to eq(200)
    end

    it "does not serve the registry when the plugin is disabled" do
      sign_in(moderator)
      SiteSetting.pyrite_extensions_enabled = false

      get "/admin/plugins/discourse-pyrite-ide-extensions/registry"

      expect(response.status).to eq(404)
    end
  end

  describe "#install" do
    it "serves the app shell to anyone, including ids with dots" do
      get "/pyrite/install/com.example.hello"

      expect(response.status).to eq(200)
    end

    it "is not served when the plugin is disabled" do
      SiteSetting.pyrite_extensions_enabled = false

      get "/pyrite/install/com.example.hello"

      expect(response.status).to eq(404)
    end
  end

  describe "#new" do
    it "is hidden from anonymous visitors" do
      get "/pyrite/new"

      expect(response.status).to eq(404)
    end

    it "serves the app shell to users allowed to publish" do
      sign_in(user)

      get "/pyrite/new"

      expect(response.status).to eq(200)
    end

    it "refuses users below the publishing trust level" do
      sign_in(newcomer)

      get "/pyrite/new"

      expect(response.status).to eq(403)
    end
  end
end
