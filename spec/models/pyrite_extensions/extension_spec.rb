# frozen_string_literal: true

RSpec.describe PyriteExtensions::Extension do
  subject(:extension) { Fabricate.build(:pyrite_extension) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:summary).is_at_most(280) }

  describe "validations" do
    it "accepts well formed ext ids and rejects others" do
      is_expected.to allow_values(
        "com.example.hello",
        "a",
        "my-ext_1.sub",
        "@scope/name",
        "@my-org/my.plugin_1",
      ).for(:ext_id)
      is_expected.not_to allow_values(
        "Com.Example",
        "bad id",
        ".leading",
        "trailing.",
        "@scope",
        "scope/name",
        "@Scope/name",
        "@scope/",
        "a/b/c",
        "nul",
        "",
      ).for(:ext_id)
    end

    it "requires ext_id to be unique" do
      Fabricate(:pyrite_extension, ext_id: "com.example.taken")
      duplicate = Fabricate.build(:pyrite_extension, ext_id: "com.example.taken")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ext_id]).to eq(
        [I18n.t("pyrite_extensions.errors.ext_id_taken_validation")],
      )
    end

    it "only accepts http(s) urls for repo_url and homepage_url" do
      is_expected.to allow_values("https://example.com/a", "http://example.com", nil, "").for(
        :repo_url,
      )
      is_expected.not_to allow_values("ftp://example.com", "javascript:alert(1)", "not a url").for(
        :repo_url,
      )
      is_expected.not_to allow_values("ftp://example.com").for(:homepage_url)
    end
  end

  describe "#releases_newest_first" do
    it "orders by semantic version rather than insertion order" do
      extension = Fabricate(:pyrite_extension)
      %w[1.0.0 2.0.0 1.0.1 2.0.0-rc.1 1.10.0 1.9.0].each do |version|
        Fabricate(:pyrite_release, extension:, version:)
      end

      expect(extension.reload.releases_newest_first.map(&:version)).to eq(
        %w[2.0.0 2.0.0-rc.1 1.10.0 1.9.0 1.0.1 1.0.0],
      )
    end
  end

  describe "#visible_to_public?" do
    it "is true only for a topic-backed extension that is not delisted or taken down" do
      expect(Fabricate(:pyrite_extension)).to be_visible_to_public
      expect(Fabricate(:pyrite_extension, topic: nil)).not_to be_visible_to_public
      expect(Fabricate(:pyrite_extension, moderation_level: :delisted)).not_to be_visible_to_public
      expect(Fabricate(:pyrite_extension, moderation_level: :takedown)).not_to be_visible_to_public
      expect(Fabricate(:pyrite_extension, moderation_level: :withdrawn)).to be_visible_to_public
    end
  end
end
