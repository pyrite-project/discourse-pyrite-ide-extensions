# frozen_string_literal: true

RSpec.describe "Ordinary pages for staff with the registry enabled" do
  fab!(:admin)
  fab!(:category)

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  # Staff pages list plugins by name, which needs the plugin's client strings;
  # a missing one used to turn every page into a 500 for staff.
  it "loads the home page" do
    sign_in(admin)

    get "/latest"

    expect(response.status).to eq(200)
  end

  it "loads the admin plugins page" do
    sign_in(admin)

    get "/admin/plugins"

    expect(response.status).to eq(200)
  end
end
