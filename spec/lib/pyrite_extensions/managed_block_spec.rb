# frozen_string_literal: true

RSpec.describe PyriteExtensions::ManagedBlock do
  fab!(:owner, :user)
  fab!(:extension) do
    Fabricate(
      :pyrite_extension,
      owner:,
      summary: "Says hello",
      repo_url: "https://example.com/repo",
      license: "MIT",
    )
  end
  fab!(:release) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }

  before { extension.update!(latest_release: release) }

  describe ".compose" do
    it "puts the managed block above the author's description" do
      raw = described_class.compose(extension, "  My **description**  ")

      expect(raw).to start_with(described_class::START_MARKER)
      expect(raw).to end_with("#{described_class::END_MARKER}\n\nMy **description**")
      expect(raw).to include("| **Summary** | Says hello |")
      expect(raw).to include("@#{owner.username} · [Repository](<https://example.com/repo>) · MIT")
      expect(raw).to include("| **Compatibility** | Windows · Linux |")
      expect(raw).to include("| **Permissions** | `ui.view` |")
      expect(raw).to include(
        "[Open in Pyrite IDE](#{Discourse.base_url}/pyrite/install/#{extension.ext_id})",
      )
    end

    it "returns only the block when there is no description" do
      expect(described_class.compose(extension, nil)).to end_with(described_class::END_MARKER)
    end

    it "escapes pipes and collapses newlines in table cells" do
      extension.update!(summary: "a | b\nsecond line")

      expect(described_class.compose(extension, nil)).to include(
        "| **Summary** | a \\| b second line |",
      )
    end

    it "omits release rows when the extension has no release" do
      bare = Fabricate(:pyrite_extension)

      raw = described_class.compose(bare, nil)

      expect(raw).not_to include("**Latest**")
      expect(raw).not_to include("**Install**")
    end
  end

  describe "callouts" do
    {
      notice: "note",
      deprecated: "warning",
      withdrawn: "danger",
      takedown: "danger",
    }.each do |level, callout|
      it "uses a #{callout} callout for #{level}" do
        extension.update!(moderation_level: level)

        expect(described_class.render(extension)).to include("> [!#{callout}] ")
      end
    end

    it "renders a severity-titled danger callout with a single-line message for advisories" do
      release.update!(
        moderation_level: :advisory,
        moderation_severity: "high",
        moderation_message: "Line one\n\n  line   two",
      )

      expect(described_class.render(extension.reload)).to include(
        "> [!danger] High advisory: Line one line two",
      )
    end

    it "renders no callout for an unmoderated extension" do
      expect(described_class.render(extension)).not_to include("> [!")
    end
  end

  describe "install row" do
    it "is hidden when the release blocks install" do
      release.update!(moderation_level: :withdrawn)

      expect(described_class.render(extension.reload)).not_to include("**Install**")
    end

    it "is shown for a deprecated release" do
      release.update!(moderation_level: :deprecated)

      expect(described_class.render(extension.reload)).to include("**Install**")
    end
  end

  describe ".replace_in" do
    it "replaces the markers in place and preserves the author's text on both sides" do
      raw =
        "Intro\n\n#{described_class::START_MARKER}\nold\n#{described_class::END_MARKER}\n\nAuthor text"
      extension.update!(summary: "New summary")

      result = described_class.replace_in(raw, extension)

      expect(result).to start_with("Intro\n\n#{described_class::START_MARKER}")
      expect(result).to end_with("#{described_class::END_MARKER}\n\nAuthor text")
      expect(result).to include("New summary")
      expect(result).not_to include("old\n")
      expect(result.scan(described_class::START_MARKER).size).to eq(1)
    end

    it "prepends the block when the post has no markers" do
      result = described_class.replace_in("Just text", extension)

      expect(result).to start_with(described_class::START_MARKER)
      expect(result).to end_with("\n\nJust text")
    end

    it "does not interpret backslashes in the new block as backreferences" do
      extension.update!(summary: 'back\\1slash')
      raw = "#{described_class::START_MARKER}\nold\n#{described_class::END_MARKER}"

      expect(described_class.replace_in(raw, extension)).to include('back\\1slash')
    end
  end
end
