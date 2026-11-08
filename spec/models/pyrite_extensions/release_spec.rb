# frozen_string_literal: true

RSpec.describe PyriteExtensions::Release do
  subject(:release) { Fabricate.build(:pyrite_release) }

  describe "validations" do
    it "requires a semantic version" do
      is_expected.to allow_values("1.0.0", "1.0.0-rc.1").for(:version)
      is_expected.not_to allow_values("1.0", "v1.0.0", "1.0.0+build", "").for(:version)
    end

    it "requires a 64 character hex sha256" do
      is_expected.to allow_values("a" * 64).for(:sha256)
      is_expected.not_to allow_values("a" * 63, "g" * 64, nil).for(:sha256)
    end

    it "requires the version to be unique per extension only" do
      existing = Fabricate(:pyrite_release, version: "1.0.0")

      same_extension =
        Fabricate.build(:pyrite_release, extension: existing.extension, version: "1.0.0")
      other_extension = Fabricate.build(:pyrite_release, version: "1.0.0")

      expect(same_extension).not_to be_valid
      expect(same_extension.errors[:version]).to eq(
        [I18n.t("pyrite_extensions.errors.version_exists")],
      )
      expect(other_extension).to be_valid
    end

    it "does not allow a release to be delisted" do
      release.moderation_level = :delisted

      expect(release).not_to be_valid
      expect(release.errors[:moderation_level]).to be_present
    end
  end

  describe "Moderatable" do
    it "requires a known severity for advisories only" do
      release.moderation_level = :advisory
      expect(release).not_to be_valid

      release.moderation_severity = "bogus"
      expect(release).not_to be_valid

      release.moderation_severity = "critical"
      expect(release).to be_valid

      release.moderation_level = :notice
      expect(release).not_to be_valid
      expect(release.errors[:moderation_severity]).to be_present
    end

    it "reports blocking and moderated levels" do
      expect(release).not_to be_moderated
      expect(release).not_to be_blocks_install

      release.moderation_level = :deprecated
      expect(release).to be_moderated
      expect(release).not_to be_blocks_install

      %i[withdrawn takedown].each do |level|
        release.moderation_level = level
        expect(release).to be_blocks_install
      end
    end
  end

  describe "#effective_state" do
    fab!(:extension, :pyrite_extension)
    fab!(:release) { Fabricate(:pyrite_release, extension:) }

    it "uses the release when it is more severe than its extension" do
      extension.update!(moderation_level: :notice, moderation_message: "package")
      release.update!(moderation_level: :withdrawn, moderation_message: "release")

      expect(release.effective_state).to have_attributes(
        level: :withdrawn,
        message: "release",
        scope: :release,
      )
    end

    it "uses the extension when it is more severe than the release" do
      extension.update!(moderation_level: :takedown, moderation_message: "package")
      release.update!(
        moderation_level: :advisory,
        moderation_severity: "low",
        moderation_message: "release",
      )

      expect(release.effective_state).to have_attributes(
        level: :takedown,
        message: "package",
        scope: :package,
      )
    end

    it "prefers the release on a tie" do
      extension.update!(moderation_level: :deprecated, moderation_message: "package")
      release.update!(moderation_level: :deprecated, moderation_message: "release")

      expect(release.effective_state).to have_attributes(scope: :release, message: "release")
    end

    it "blocks install when either side is withdrawn, delisted, or taken down" do
      expect(release).not_to be_blocks_install

      extension.update!(moderation_level: :delisted)

      expect(release.reload).to be_blocks_install
    end
  end
end
