# frozen_string_literal: true

module PyriteExtensions
  # Renders the registry-owned region at the top of an extension's first post. It is plain
  # Markdown between comment markers, so it works in search, email and the API, and the
  # author's own description below it is never touched.
  module ManagedBlock
    START_MARKER = '<!-- pyrite:meta:start -->'
    END_MARKER = '<!-- pyrite:meta:end -->'
    REGION = /#{Regexp.escape(START_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
    VERSIONS_SHOWN = 10
    PLATFORM_LABELS = {
      'windows' => 'Windows',
      'linux' => 'Linux',
      'macos' => 'macOS',
      'android' => 'Android'
    }.freeze
    CALLOUT_TYPES = {
      notice: 'note',
      deprecated: 'warning',
      advisory: 'danger',
      withdrawn: 'danger',
      takedown: 'danger'
    }.freeze

    module_function

    def compose(extension, description)
      [render(extension), description.to_s.strip].reject(&:blank?).join("\n\n")
    end

    def replace_in(raw, extension)
      block = render(extension)
      if raw.match?(REGION)
        raw.sub(REGION) { block }
      else
        [block, raw.to_s.strip].reject(&:blank?).join("\n\n")
      end
    end

    def render(extension)
      latest = extension.latest_release
      callout = callout_for(state_for(extension, latest))
      lines = [START_MARKER]
      lines.push(callout, '') if callout
      lines.concat(table_for(extension, latest))
      lines.concat(['', versions_for(extension)]) if extension.releases.any?
      lines << END_MARKER
      lines.join("\n")
    end

    def table_for(extension, latest)
      rows = [[t(:summary), extension.summary]]
      if latest
        rows << [t(:latest), latest_cell(latest)]
        rows << [
          t(:compatibility),
          latest.manifest_platforms.map { |p| PLATFORM_LABELS.fetch(p, p) }.join(' · ')
        ]
        rows << [t(:permissions), permissions_cell(latest)]
      end
      rows << [t(:author), author_cell(extension)]
      rows << [t(:install), install_cell(extension, latest)] if latest && !latest.blocks_install?
      ['| | |', '|---|---|', *rows.map { |label, value| "| **#{label}** | #{cell(value)} |" }]
    end

    def latest_cell(latest)
      size = ActiveSupport::NumberHelper.number_to_human_size(latest.size)
      "#{latest.version} (#{latest.published_at.to_date.iso8601}), #{size}"
    end

    def permissions_cell(latest)
      latest.manifest_permissions.map { |permission| "`#{permission}`" }.join(', ').presence ||
        t(:none)
    end

    def author_cell(extension)
      [
        "@#{extension.owner.username}",
        extension.repo_url.presence && "[Repository](<#{extension.repo_url}>)",
        extension.license.presence
      ].compact.join(' · ')
    end

    def install_cell(extension, latest)
      base = "#{Discourse.base_url}/pyrite"
      package = "#{base}/registry/extensions/#{extension.ext_id}/releases/#{latest.version}/package"
      "[#{t(:open_in_ide)}](#{base}/install/#{extension.ext_id}) · [.pyrix](#{package}.pyrix) · [.zip](#{package}.zip)"
    end

    def versions_for(extension)
      rows =
        extension
        .releases_newest_first
        .first(VERSIONS_SHOWN)
        .map do |version|
          state = version.effective_state
          "| #{version.version} | #{version.published_at.to_date.iso8601} | #{status_label(state.level)} |"
        end
      [
        "[details=\"#{t(:versions)}\"]",
        '',
        "| #{t(:version)} | #{t(:date)} | #{t(:status)} |",
        '|---|---|---|',
        *rows,
        '',
        '[/details]'
      ].join("\n")
    end

    def callout_for(state)
      type = CALLOUT_TYPES[state.level]
      return if type.nil?

      title =
        (
          if state.severity
            "#{state.severity.capitalize} #{status_label(state.level).downcase}"
          else
            status_label(state.level)
          end
        )
      text = [title, state.message.to_s.squish.presence].compact.join(': ')
      "> [!#{type}] #{text}"
    end

    def state_for(extension, latest)
      return latest.effective_state if latest

      Release::EffectiveState.new(
        level: extension.moderation_level.to_sym,
        severity: extension.moderation_severity,
        message: extension.moderation_message,
        scope: :package
      )
    end

    def status_label(level)
      I18n.t("pyrite_extensions.moderation.status.#{level}", locale: SiteSetting.default_locale)
    end

    def t(key)
      I18n.t("pyrite_extensions.block.#{key}", locale: SiteSetting.default_locale)
    end

    def cell(value)
      value.to_s.gsub('|', '\\|').gsub(/\s*\R\s*/, ' ').strip
    end
  end
end
