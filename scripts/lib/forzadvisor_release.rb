# frozen_string_literal: true

require "base64"
require "date"
require "fileutils"
require "json"
require "net/http"
require "openssl"
require "open3"
require "pathname"
require "rexml/document"
require "time"
require "uri"
require "zlib"

module ForzAdvisorRelease
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class PreflightError < Error
    attr_reader :result

    def initialize(message, result: nil)
      @result = result
      super(message)
    end
  end
  class APIError < Error; end

  module Redactor
    module_function

    SENSITIVE_PATTERNS = [
      /Bearer\s+[^\s]+/i,
      /\b(?:ASC_KEY_ID|ASC_ISSUER_ID|ASC_KEY_PATH)\s*=\s*[^\s]+/i,
      /\beyJ[A-Za-z0-9_.-]+/
    ].freeze

    def call(value)
      SENSITIVE_PATTERNS.reduce(value.to_s) { |text, pattern| text.gsub(pattern, "[REDACTED]") }
    end
  end

  class Config
    EXACT_KEYS = {
      "" => %w[schema_version app repository release public_urls xcode xcode_cloud ci app_store testflight metadata screenshots],
      "app" => %w[id name bundle_id team_id],
      "repository" => %w[canonical_root remote_name remote_url release_ref],
      "release" => %w[marketing_version source_build_number current_app_store_build_number price submission_policy app_store_release_type content_rights age_rating review_contact privacy export_compliance expected_build_audience],
      "release.price" => %w[model base_territory amount price_point_id manual_price_id],
      "release.age_rating" => %w[completed_in_app_store_connect expected_app_store_rating],
      "release.review_contact" => %w[recorded_in_app_store_connect],
      "release.privacy" => %w[published_in_app_store_connect collected_data purpose linked_to_user tracking human_attestation_date],
      "release.export_compliance" => %w[uses_non_exempt_encryption],
      "public_urls" => %w[marketing privacy support],
      "xcode" => %w[project app_target local_scheme cloud_scheme test_plan privacy_manifest],
      "xcode_cloud" => %w[product_id repository_id workflows],
      "xcode_cloud.workflows" => %w[verify release_candidate],
      "xcode_cloud.workflows.verify" => %w[id name],
      "xcode_cloud.workflows.release_candidate" => %w[id name],
      "ci" => %w[provider verify_workflow runner xcode_version release_candidate_mode],
      "app_store" => %w[version_id review_submission_id review_submission_item_id],
      "testflight" => %w[internal_group], "testflight.internal_group" => %w[id name],
      "metadata" => %w[path required_sections],
      "screenshots" => %w[directory width height require_opaque ordered_files]
    }.freeze
    REQUIRED_PATHS = %w[
      app.id app.name app.bundle_id app.team_id
      repository.canonical_root repository.remote_name repository.remote_url repository.release_ref
      release.marketing_version release.source_build_number release.current_app_store_build_number
      release.price.model release.price.base_territory release.price.amount release.price.price_point_id release.price.manual_price_id release.submission_policy release.app_store_release_type
      release.content_rights release.age_rating.completed_in_app_store_connect
      release.age_rating.expected_app_store_rating release.export_compliance.uses_non_exempt_encryption
      release.expected_build_audience
      release.review_contact.recorded_in_app_store_connect
      release.privacy.published_in_app_store_connect release.privacy.collected_data
      release.privacy.purpose release.privacy.linked_to_user release.privacy.tracking
      release.privacy.human_attestation_date
      public_urls.marketing public_urls.privacy public_urls.support
      xcode.project xcode.app_target xcode.local_scheme xcode.cloud_scheme xcode.test_plan xcode.privacy_manifest
      xcode_cloud.workflows.verify.id xcode_cloud.workflows.verify.name
      xcode_cloud.workflows.release_candidate.id xcode_cloud.workflows.release_candidate.name
      ci.provider ci.verify_workflow ci.runner ci.xcode_version ci.release_candidate_mode
      app_store.version_id app_store.review_submission_id app_store.review_submission_item_id
      xcode_cloud.product_id xcode_cloud.repository_id testflight.internal_group.id testflight.internal_group.name
      metadata.path metadata.required_sections screenshots.directory screenshots.width screenshots.height
      screenshots.require_opaque screenshots.ordered_files
    ].freeze

    attr_reader :data, :path

    def initialize(path)
      @path = File.expand_path(path)
      @data = JSON.parse(File.read(@path))
      validate!
    rescue Errno::ENOENT
      raise ConfigurationError, "release config not found: #{@path}"
    rescue JSON::ParserError => error
      raise ConfigurationError, "invalid release config JSON: #{error.message}"
    end

    def fetch(*keys)
      keys.map(&:to_s).reduce(data) { |value, key| value.fetch(key) }
    rescue KeyError
      raise ConfigurationError, "missing release config value: #{keys.join('.')}"
    end

    private

    def validate!
      raise ConfigurationError, "unsupported release config schema" unless data["schema_version"] == 1

      REQUIRED_PATHS.each do |path|
        value = path.split(".").reduce(data) { |item, key| item.is_a?(Hash) ? item[key] : nil }
        missing = value.nil? || value.respond_to?(:empty?) && value.empty?
        raise ConfigurationError, "missing release config value: #{path}" if missing
      end
      raise ConfigurationError, "release price must be FREE at 0.0" unless fetch("release", "price", "model") == "FREE" && fetch("release", "price", "amount") == "0.0"
      raise ConfigurationError, "submission policy must require approval" unless fetch("release", "submission_policy") == "EXPLICIT_HUMAN_APPROVAL"
      raise ConfigurationError, "unsupported App Store release type" unless fetch("release", "app_store_release_type") == "AFTER_APPROVAL"
      raise ConfigurationError, "privacy tracking must be false" unless fetch("release", "privacy", "tracking") == false
      validate_domain!
      %w[marketing privacy support].each do |key|
        uri = URI(fetch("public_urls", key))
        raise ConfigurationError, "public URL must be absolute HTTPS: #{key}" unless uri.scheme == "https" && uri.host && uri.path.start_with?("/")
      rescue URI::InvalidURIError
        raise ConfigurationError, "public URL must be absolute HTTPS: #{key}"
      end
    end

    def validate_domain!
      EXACT_KEYS.each do |path, expected|
        value = path.empty? ? data : path.split(".").reduce(data) { |item, key| item.fetch(key) }
        raise ConfigurationError, "unexpected or missing config keys at #{path.empty? ? 'root' : path}" unless value.is_a?(Hash) && value.keys.sort == expected.sort
      end
      uuid = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      %w[product_id repository_id].each { |key| raise ConfigurationError, "invalid xcode_cloud.#{key}" unless fetch("xcode_cloud", key).match?(uuid) }
      %w[version_id review_submission_id].each { |key| raise ConfigurationError, "invalid app_store.#{key}" unless fetch("app_store", key).match?(uuid) }
      raise ConfigurationError, "invalid review submission item id" unless fetch("app_store", "review_submission_item_id").match?(/\A[A-Za-z0-9_-]{40,}\z/)
      %w[verify release_candidate].each { |key| raise ConfigurationError, "invalid workflow id: #{key}" unless fetch("xcode_cloud", "workflows", key, "id").match?(uuid) }
      raise ConfigurationError, "invalid TestFlight group id" unless fetch("testflight", "internal_group", "id").match?(uuid)
      raise ConfigurationError, "invalid App Store app id" unless fetch("app", "id").match?(/\A\d+\z/)
      raise ConfigurationError, "invalid team id" unless fetch("app", "team_id").match?(/\A[A-Z0-9]{10}\z/)
      raise ConfigurationError, "invalid bundle id" unless fetch("app", "bundle_id").match?(/\A[a-zA-Z0-9]+(?:[.-][a-zA-Z0-9]+)+\z/)
      raise ConfigurationError, "invalid app name" unless fetch("app", "name").is_a?(String) && !fetch("app", "name").strip.empty?
      raise ConfigurationError, "invalid repository remote" unless fetch("repository", "remote_name") == "origin" && fetch("repository", "remote_url").match?(%r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?\z})
      raise ConfigurationError, "invalid local preflight ref" unless fetch("repository", "release_ref").match?(/\A[A-Za-z0-9._\/-]+\z/)
      raise ConfigurationError, "unsupported CI provider" unless fetch("ci", "provider") == "GITHUB_ACTIONS"
      raise ConfigurationError, "invalid GitHub verify workflow" unless fetch("ci", "verify_workflow") == ".github/workflows/release-verify.yml"
      raise ConfigurationError, "unsupported GitHub runner" unless fetch("ci", "runner") == "macos-26"
      raise ConfigurationError, "unsupported CI Xcode version" unless fetch("ci", "xcode_version") == "26.6"
      raise ConfigurationError, "unsupported release candidate mode" unless fetch("ci", "release_candidate_mode") == "LOCAL_XCODE"
      raise ConfigurationError, "invalid marketing version" unless fetch("release", "marketing_version").match?(/\A\d+\.\d+\.\d+\z/)
      %w[source_build_number current_app_store_build_number].each { |key| raise ConfigurationError, "invalid #{key}" unless fetch("release", key).match?(/\A[1-9]\d*\z/) }
      raise ConfigurationError, "unsupported content rights" unless %w[DOES_NOT_USE_THIRD_PARTY_CONTENT USES_THIRD_PARTY_CONTENT].include?(fetch("release", "content_rights"))
      raise ConfigurationError, "unsupported age rating" unless %w[FOUR_PLUS NINE_PLUS THIRTEEN_PLUS SIXTEEN_PLUS EIGHTEEN_PLUS].include?(fetch("release", "age_rating", "expected_app_store_rating"))
      raise ConfigurationError, "unsupported build audience" unless fetch("release", "expected_build_audience") == "APP_STORE_ELIGIBLE"
      raise ConfigurationError, "invalid free price identity" unless fetch("release", "price", "manual_price_id").match?(/\A[A-Za-z0-9_-]{40,}\z/)
      raise ConfigurationError, "invalid price point identity" unless fetch("release", "price", "price_point_id").match?(/\A[A-Za-z0-9_-]{40,}\z/)
      raise ConfigurationError, "export compliance must be boolean" unless [true, false].include?(fetch("release", "export_compliance", "uses_non_exempt_encryption"))
      raise ConfigurationError, "age rating attestation must be true" unless fetch("release", "age_rating", "completed_in_app_store_connect") == true
      raise ConfigurationError, "review contact attestation must be true" unless fetch("release", "review_contact", "recorded_in_app_store_connect") == true
      raise ConfigurationError, "privacy publication attestation must be true" unless fetch("release", "privacy", "published_in_app_store_connect") == true
      raise ConfigurationError, "privacy linked_to_user must be boolean" unless [true, false].include?(fetch("release", "privacy", "linked_to_user"))
      raise ConfigurationError, "unsupported privacy purpose" unless fetch("release", "privacy", "purpose") == "APP_FUNCTIONALITY"
      raise ConfigurationError, "invalid privacy attestation date" unless DatePattern.valid?(fetch("release", "privacy", "human_attestation_date"))
      raise ConfigurationError, "invalid screenshot dimensions" unless fetch("screenshots", "width").is_a?(Integer) && fetch("screenshots", "width").positive? && fetch("screenshots", "height").is_a?(Integer) && fetch("screenshots", "height").positive?
      raise ConfigurationError, "require_opaque must be true" unless fetch("screenshots", "require_opaque") == true
      raise ConfigurationError, "invalid base territory" unless fetch("release", "price", "base_territory").match?(/\A[A-Z]{3}\z/)
      %w[project test_plan privacy_manifest].each do |key|
        path = fetch("xcode", key)
        raise ConfigurationError, "invalid xcode path: #{key}" unless path.is_a?(String) && !path.empty? && !Pathname.new(path).absolute? && !path.split("/").include?("..")
      end
      data_types = fetch("release", "privacy", "collected_data")
      raise ConfigurationError, "invalid privacy collected_data" unless data_types.is_a?(Array) && !data_types.empty? && data_types.uniq.length == data_types.length && (data_types - %w[GAMEPLAY_CONTENT OTHER_USER_CONTENT]).empty?
      files = fetch("screenshots", "ordered_files")
      raise ConfigurationError, "invalid screenshot file list" unless files.is_a?(Array) && !files.empty? && files.uniq.length == files.length && files.all? { |name| name.match?(/\A\d{2}-[a-z0-9-]+\.png\z/) }
      sections = fetch("metadata", "required_sections")
      raise ConfigurationError, "invalid metadata section list" unless sections.is_a?(Array) && !sections.empty? && sections.uniq.length == sections.length && sections.all? { |item| item.is_a?(String) && !item.empty? }
    end
  end

  class CommandRunner
    def call(*command, chdir:)
      output, error, status = Open3.capture3(*command, chdir: chdir)
      raise PreflightError, "#{command.first} failed: #{Redactor.call(error.strip)}" unless status.success?
      output
    end
  end

  class GitRepository
    attr_reader :root

    def initialize(root, runner: CommandRunner.new)
      @root = File.realpath(root)
      @runner = runner
    end

    def assert_release_state!(config, ref: nil, require_tag: false)
      expected_root = File.realpath(File.expand_path(config.fetch("repository", "canonical_root")))
      raise PreflightError, "not running from canonical repository: #{expected_root}" unless root == expected_root

      remote = config.fetch("repository", "remote_name")
      expected_url = normalize_url(config.fetch("repository", "remote_url"))
      actual_url = normalize_url(run("git", "remote", "get-url", remote).strip)
      raise PreflightError, "#{remote} does not match configured repository" unless actual_url == expected_url
      raise PreflightError, "working tree has uncommitted changes" unless run("git", "status", "--porcelain").strip.empty?

      selected_ref = ref || config.fetch("repository", "release_ref")
      head = run("git", "rev-parse", "HEAD^{commit}").strip
      local_branch = run("git", "branch", "--show-current").strip
      kind = tag_exists?(selected_ref) ? "tag" : "branch"
      raise PreflightError, "cloud releases require a pushed release tag" if require_tag && kind != "tag"

      if kind == "tag"
        tag_commit = run("git", "rev-list", "-n", "1", "refs/tags/#{selected_ref}").strip
        raise PreflightError, "HEAD does not match release tag #{selected_ref}" unless tag_commit == head
        remote_commit = remote_tag_commit(remote, selected_ref)
      else
        raise PreflightError, "current branch is #{local_branch}, expected #{selected_ref}" unless local_branch == selected_ref
        remote_commit = remote_branch_commit(remote, selected_ref)
      end
      raise PreflightError, "HEAD is not the pushed #{kind} #{selected_ref}" unless remote_commit == head

      { "commit" => head, "peeled_tag_commit" => (kind == "tag" ? remote_commit : nil), "ref" => selected_ref, "ref_kind" => kind, "remote" => remote }
    end

    private

    def run(*command)
      @runner.call(*command, chdir: root)
    end

    def tag_exists?(ref)
      !run("git", "tag", "--list", ref).strip.empty?
    end

    def remote_branch_commit(remote, branch)
      parse_remote_sha(run("git", "ls-remote", "--heads", remote, "refs/heads/#{branch}"), "remote branch #{remote}/#{branch}")
    end

    def remote_tag_commit(remote, tag)
      output = run("git", "ls-remote", "--tags", remote, "refs/tags/#{tag}", "refs/tags/#{tag}^{}")
      lines = output.lines.map { |line| line.split(/\s+/, 2) }
      peeled = lines.find { |(_, name)| name.to_s.strip.end_with?("^{}") }
      sha = peeled&.first || lines.first&.first
      raise PreflightError, "remote tag not found: #{remote}/#{tag}" if sha.to_s.empty?
      sha
    end

    def parse_remote_sha(output, label)
      sha = output.split(/\s+/).first
      raise PreflightError, "#{label} not found" if sha.to_s.empty?
      sha
    end

    def normalize_url(url)
      url.to_s.sub(/\Agh:/, "https://github.com/").sub(/\.git\z/, "").sub(%r{/\z}, "").downcase
    end
  end

  class ProjectInspector
    def self.assert_no_skips!(scheme_texts:, plan:)
      scheme_texts.each do |name, text|
        raise PreflightError, "release scheme contains skipped or selected-only tests: #{name}" if text.include?("<SkippedTests>") || text.include?("<SelectedTests>") || text.match?(/skipped\s*=\s*"YES"/)
      end
      serialized = JSON.generate(plan)
      raise PreflightError, "release test plan contains skipped or disabled tests" if serialized.match?(/"(?:skippedTests|skipEnabled)"\s*:\s*(?:\[|true)/) || serialized.match?(/"enabled"\s*:\s*false/)
      true
    end
    def initialize(root:, config:)
      @root = root
      @config = config
    end

    def call
      project = absolute(@config.fetch("xcode", "project"))
      pbxproj = File.join(project, "project.pbxproj")
      raise PreflightError, "Xcode project is missing" unless File.file?(pbxproj)
      expected_assignments = {
        "MARKETING_VERSION" => @config.fetch("release", "marketing_version"),
        "CURRENT_PROJECT_VERSION" => @config.fetch("release", "source_build_number"),
        "DEVELOPMENT_TEAM" => @config.fetch("app", "team_id"),
        "PRODUCT_BUNDLE_IDENTIFIER" => @config.fetch("app", "bundle_id"),
        "CODE_SIGN_STYLE" => "Automatic",
        "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption" => "NO"
      }
      output, error, status = Open3.capture3("xcodebuild", "-project", project, "-target", @config.fetch("xcode", "app_target"), "-configuration", "Release", "-showBuildSettings", chdir: @root)
      raise PreflightError, "could not resolve Release build settings: #{Redactor.call(error)}" unless status.success?
      expected_assignments.each do |key, value|
        actual = output[/^\s*#{Regexp.escape(key)}\s*=\s*(.+?)\s*$/, 1]
        raise PreflightError, "Release app-target setting mismatch: #{key}" unless actual == value.to_s
      end

      local_scheme = scheme_path(@config.fetch("xcode", "local_scheme"))
      cloud_scheme = scheme_path(@config.fetch("xcode", "cloud_scheme"))
      test_plan = absolute(@config.fetch("xcode", "test_plan"))
      [local_scheme, cloud_scheme, test_plan].each { |path| raise PreflightError, "required release artifact is missing: #{relative(path)}" unless File.file?(path) }
      unless File.read(local_scheme).include?("container:#{@config.fetch('xcode', 'test_plan')}")
        raise PreflightError, "local release scheme does not use the configured test plan"
      end
      plan = JSON.parse(File.read(test_plan))
      self.class.assert_no_skips!(scheme_texts: { File.basename(local_scheme) => File.read(local_scheme), File.basename(cloud_scheme) => File.read(cloud_scheme) }, plan: plan)
      targets = plan.fetch("testTargets", []).map { |item| item.dig("target", "name") }
      %w[forzadvisorTests forzadvisorUITests].each do |target|
        raise PreflightError, "release test plan is missing #{target}" unless targets.include?(target)
      end
      { "marketing_version" => expected_assignments["MARKETING_VERSION"], "source_build_number" => expected_assignments["CURRENT_PROJECT_VERSION"], "schemes" => [File.basename(local_scheme), File.basename(cloud_scheme)], "test_targets" => targets }
    rescue JSON::ParserError, KeyError => error
      raise PreflightError, "invalid release test plan: #{error.message}"
    end

    private

    def absolute(path)
      File.join(@root, path)
    end

    def scheme_path(name)
      File.join(@root, @config.fetch("xcode", "project"), "xcshareddata", "xcschemes", "#{name}.xcscheme")
    end

    def relative(path)
      path.delete_prefix("#{@root}/")
    end
  end

  class MetadataInspector
    LIMITS = { "App Name" => 30, "Subtitle" => 30, "Promotional Text" => 170, "Description" => 4000, "Keywords" => 100 }.freeze

    def self.sections(path)
      result = {}
      current = nil
      File.read(path).each_line do |line|
        if (match = line.match(/^##\s+(.+?)\s*$/))
          current = match[1]
          result[current] = +""
        elsif current
          result[current] << line
        end
      end
      result.transform_values(&:strip)
    end

    def initialize(root:, config:)
      @root = root
      @config = config
    end

    def call
      path = File.join(@root, @config.fetch("metadata", "path"))
      sections = self.class.sections(path)
      @config.fetch("metadata", "required_sections").each do |name|
        raise PreflightError, "metadata section is missing or empty: #{name}" if sections[name].to_s.strip.empty?
      end
      LIMITS.each do |name, limit|
        value = sections.fetch(name).strip
        raise PreflightError, "metadata #{name} exceeds #{limit} characters" if value.length > limit
      end
      urls = @config.fetch("public_urls")
      raise PreflightError, "metadata privacy URL does not match release config" unless sections.fetch("Privacy Policy").include?(urls.fetch("privacy"))
      raise PreflightError, "metadata support URL does not match release config" unless sections.fetch("Support URL").include?(urls.fetch("support"))
      { "path" => @config.fetch("metadata", "path"), "lengths" => LIMITS.to_h { |name, _| [name, sections.fetch(name).strip.length] } }
    rescue Errno::ENOENT
      raise PreflightError, "metadata file is missing"
    end

    private

  end

  class PNGInspector
    SIGNATURE = "\x89PNG\r\n\x1a\n".b

    def self.call(path)
      data = File.binread(path)
      raise PreflightError, "invalid PNG: #{File.basename(path)}" unless data.start_with?(SIGNATURE)
      offset = SIGNATURE.bytesize
      idat = +"".b
      header = nil
      transparency = false
      while offset < data.bytesize
        length = data.byteslice(offset, 4).unpack1("N")
        type = data.byteslice(offset + 4, 4)
        body = data.byteslice(offset + 8, length)
        header = body.unpack("NNCCCCC") if type == "IHDR"
        idat << body if type == "IDAT"
        transparency = true if type == "tRNS"
        offset += 12 + length
        break if type == "IEND"
      end
      raise PreflightError, "PNG is missing IHDR: #{File.basename(path)}" unless header
      width, height, bit_depth, color_type, compression, filter, interlace = header
      raise PreflightError, "unsupported PNG encoding: #{File.basename(path)}" unless bit_depth == 8 && compression.zero? && filter.zero? && interlace.zero?
      channels = { 2 => 3, 6 => 4 }[color_type]
      raise PreflightError, "screenshot PNG must be RGB or RGBA: #{File.basename(path)}" unless channels
      opaque = !transparency
      if [4, 6].include?(color_type)
        rows = unfilter(Zlib::Inflate.inflate(idat), width, height, channels)
        alpha_offset = channels - 1
        opaque = rows.all? { |row| (alpha_offset...row.length).step(channels).all? { |index| row.getbyte(index) == 255 } }
      end
      { "width" => width, "height" => height, "opaque" => opaque }
    rescue Zlib::Error, NoMethodError, RangeError => error
      raise PreflightError, "invalid PNG #{File.basename(path)}: #{error.message}"
    end

    def self.unfilter(raw, width, height, channels)
      stride = width * channels
      previous = "\x00".b * stride
      offset = 0
      Array.new(height) do
        filter = raw.getbyte(offset)
        bytes = raw.byteslice(offset + 1, stride)
        raise PreflightError, "truncated PNG data" unless bytes&.bytesize == stride
        index = 0
        while index < stride
          left = index >= channels ? bytes.getbyte(index - channels) : 0
          up = previous.getbyte(index)
          upper_left = index >= channels ? previous.getbyte(index - channels) : 0
          prediction = case filter
                       when 0 then 0
                       when 1 then left
                       when 2 then up
                       when 3 then (left + up) / 2
                       when 4 then paeth(left, up, upper_left)
                       else raise PreflightError, "unsupported PNG row filter"
                       end
          bytes.setbyte(index, (bytes.getbyte(index) + prediction) & 0xff)
          index += 1
        end
        previous = bytes
        offset += stride + 1
        bytes
      end
    end

    def self.paeth(left, up, upper_left)
      estimate = left + up - upper_left
      distances = [(estimate - left).abs, (estimate - up).abs, (estimate - upper_left).abs]
      [left, up, upper_left][distances.index(distances.min)]
    end
    private_class_method :unfilter, :paeth
  end

  class ScreenshotInspector
    def initialize(root:, config:)
      @root = root
      @config = config
    end

    def call
      directory = File.join(@root, @config.fetch("screenshots", "directory"))
      expected = @config.fetch("screenshots", "ordered_files")
      actual = Dir[File.join(directory, "*.png")].map { |path| File.basename(path) }.sort
      raise PreflightError, "screenshot set or order does not match release config" unless actual == expected
      details = expected.map do |filename|
        info = PNGInspector.call(File.join(directory, filename))
        unless info["width"] == @config.fetch("screenshots", "width") && info["height"] == @config.fetch("screenshots", "height")
          raise PreflightError, "screenshot dimensions do not match: #{filename}"
        end
        if @config.fetch("screenshots", "require_opaque") && !info["opaque"]
          raise PreflightError, "screenshot contains transparent pixels: #{filename}"
        end
        info.merge("file" => filename)
      end
      { "count" => details.length, "files" => details }
    end
  end

  class PrivacyInspector
    def initialize(root:, config:)
      @root = root
      @config = config
    end

    def call
      relative = @config.fetch("xcode", "privacy_manifest")
      path = File.join(@root, relative)
      manifest = Plist.parse(File.read(path))
      privacy = @config.fetch("release", "privacy")
      expected_types = privacy.fetch("collected_data").map { |name| "NSPrivacyCollectedDataType#{name.split('_').map(&:capitalize).join}" }.sort
      entries = manifest.fetch("NSPrivacyCollectedDataTypes")
      actual_types = entries.map { |item| item.fetch("NSPrivacyCollectedDataType") }.sort
      raise PreflightError, "privacy manifest collected-data types drift from published label" unless actual_types == expected_types
      expected_purpose = "NSPrivacyCollectedDataTypePurpose#{privacy.fetch('purpose').split('_').map(&:capitalize).join}"
      entries.each do |entry|
        raise PreflightError, "privacy manifest linked-to-user value drifts from published label" unless entry["NSPrivacyCollectedDataTypeLinked"] == privacy.fetch("linked_to_user")
        raise PreflightError, "privacy manifest tracking value drifts from published label" unless entry["NSPrivacyCollectedDataTypeTracking"] == privacy.fetch("tracking")
        raise PreflightError, "privacy manifest purpose drifts from published label" unless entry.fetch("NSPrivacyCollectedDataTypePurposes") == [expected_purpose]
      end
      raise PreflightError, "privacy manifest top-level tracking drifts from published label" unless manifest["NSPrivacyTracking"] == privacy.fetch("tracking")
      raise PreflightError, "App Store privacy publication is not attested" unless privacy.fetch("published_in_app_store_connect") == true
      raise PreflightError, "privacy attestation date is invalid" unless DatePattern.valid?(privacy.fetch("human_attestation_date"))
      { "path" => relative, "published" => true, "tracking" => false, "attested_on" => privacy.fetch("human_attestation_date") }
    rescue Errno::ENOENT
      raise PreflightError, "privacy manifest is missing"
    end
  end

  module Plist
    module_function
    def parse(xml)
      root = REXML::Document.new(xml).elements["plist/*"]
      value(root)
    rescue REXML::ParseException, NoMethodError => error
      raise PreflightError, "invalid privacy manifest plist: #{error.message}"
    end
    def value(node)
      case node.name
      when "dict"
        children = node.elements.to_a
        children.each_slice(2).to_h { |key, item| [key.text, value(item)] }
      when "array" then node.elements.map { |item| value(item) }
      when "string" then node.text.to_s
      when "true" then true
      when "false" then false
      else raise PreflightError, "unsupported privacy manifest value: #{node.name}"
      end
    end
  end

  module DatePattern
    module_function

    def valid?(value)
      Date.iso8601(value.to_s)
      true
    rescue Date::Error
      false
    end
  end

  class ReleaseDeclarationInspector
    def initialize(config)
      @config = config
    end

    def call
      release = @config.fetch("release")
      raise PreflightError, "release price is not recorded as free" unless release.dig("price", "model") == "FREE" && release.dig("price", "amount") == "0.0"
      raise PreflightError, "submission policy does not require human approval" unless release["submission_policy"] == "EXPLICIT_HUMAN_APPROVAL"
      raise PreflightError, "content rights declaration is missing" if release["content_rights"].to_s.empty?
      raise PreflightError, "age rating completion is not recorded" unless release.dig("age_rating", "completed_in_app_store_connect") == true
      raise PreflightError, "review contact completion is not recorded" unless release.dig("review_contact", "recorded_in_app_store_connect") == true
      { "price" => "FREE", "submission_policy" => release["submission_policy"], "app_store_release_type" => release["app_store_release_type"], "content_rights" => release["content_rights"], "age_rating_recorded" => true, "review_contact_recorded" => true, "source_build_number" => release["source_build_number"], "current_app_store_build_number" => release["current_app_store_build_number"] }
    end
  end

  module SubmissionGuard
    module_function

    def authorize!(submit:, acknowledge_irreversible_app_review_submission:)
      unless submit && acknowledge_irreversible_app_review_submission
        raise PreflightError, "submission requires --submit and --acknowledge-irreversible-app-review-submission"
      end
      true
    end
  end

  class HTTPURLChecker
    def initialize(open_timeout: 10, read_timeout: 20, max_redirects: 5)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @max_redirects = max_redirects
    end

    def call(url, redirects: 0)
      raise PreflightError, "too many redirects for #{url}" if redirects > @max_redirects
      uri = URI(url)
      raise PreflightError, "public URL must use HTTPS: #{url}" unless uri.scheme == "https"
      request = Net::HTTP::Get.new(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: @open_timeout, read_timeout: @read_timeout) { |http| http.request(request) }
      return call(URI.join(uri, response["location"]).to_s, redirects: redirects + 1) if response.is_a?(Net::HTTPRedirection)
      raise PreflightError, "public URL returned HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)
      { "url" => url, "status" => response.code.to_i }
    rescue URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error => error
      raise PreflightError, "public URL check failed for #{url}: #{error.message}"
    end
  end

  class FixtureURLChecker
    def initialize(path)
      @responses = JSON.parse(File.read(File.expand_path(path)))
    rescue Errno::ENOENT, JSON::ParserError => error
      raise ConfigurationError, "invalid URL fixture: #{error.message}"
    end

    def call(url)
      status = @responses.fetch(url) { raise PreflightError, "URL fixture has no response for #{url}" }.to_i
      raise PreflightError, "public URL returned HTTP #{status}: #{url}" unless (200..299).cover?(status)
      { "url" => url, "status" => status, "fixture" => true }
    end
  end

  class Preflight
    CHECKS = %w[repository project metadata screenshots privacy declarations public_urls].freeze

    def initialize(root:, config:, url_checker:, git: nil)
      @root = File.realpath(root)
      @config = config
      @url_checker = url_checker
      @git = git || GitRepository.new(@root)
    end

    def run(ref: nil)
      results = {}
      errors = []
      execute(results, errors, "repository") { @git.assert_release_state!(@config, ref: ref) }
      execute(results, errors, "project") { ProjectInspector.new(root: @root, config: @config).call }
      execute(results, errors, "metadata") { MetadataInspector.new(root: @root, config: @config).call }
      execute(results, errors, "screenshots") { ScreenshotInspector.new(root: @root, config: @config).call }
      execute(results, errors, "privacy") { PrivacyInspector.new(root: @root, config: @config).call }
      execute(results, errors, "declarations") { ReleaseDeclarationInspector.new(@config).call }
      execute(results, errors, "public_urls") do
        @config.fetch("public_urls").transform_values { |url| @url_checker.call(url) }
      end
      result = { "ready" => errors.empty?, "checks" => results, "errors" => errors }
      raise PreflightError.new("preflight failed:\n- #{errors.join("\n- ")}", result: result) unless errors.empty?
      result
    end

    private

    def execute(results, errors, name)
      results[name] = { "passed" => true, "evidence" => yield }
    rescue Error => error
      results[name] = { "passed" => false }
      errors << "#{name}: #{Redactor.call(error.message)}"
    end
  end

  class Credentials
    DEFAULT_PATH = File.expand_path("~/.codex/secrets/app-store-connect.env")

    def initialize(path: ENV.fetch("FORZADVISOR_ASC_SECRETS_FILE", DEFAULT_PATH), environment: ENV)
      file_values = File.file?(File.expand_path(path)) ? dotenv(File.expand_path(path)) : {}
      @values = file_values.merge(environment.to_h.select { |key, _| key.start_with?("ASC_") })
    end

    def token(now: Time.now)
      validate!
      header = { alg: "ES256", kid: @values.fetch("ASC_KEY_ID"), typ: "JWT" }
      issued_at = now.to_i
      payload = { iss: @values.fetch("ASC_ISSUER_ID"), iat: issued_at, exp: issued_at + 900, aud: "appstoreconnect-v1" }
      signing_input = "#{base64url(header.to_json)}.#{base64url(payload.to_json)}"
      key = OpenSSL::PKey.read(File.read(File.expand_path(@values.fetch("ASC_KEY_PATH"))))
      der_signature = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
      "#{signing_input}.#{base64url(raw_signature(der_signature))}"
    rescue OpenSSL::PKey::PKeyError, Errno::ENOENT
      raise ConfigurationError, "invalid App Store Connect signing key"
    end

    private

    def validate!
      %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH].each do |key|
        raise ConfigurationError, "missing #{key} in environment or credentials file" if @values[key].to_s.empty?
      end
    end

    def dotenv(path)
      File.readlines(path).each_with_object({}) do |line, values|
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?("#") || !stripped.include?("=")
        key, value = stripped.split("=", 2)
        values[key.strip] = value.strip.gsub(/\A[\"']|[\"']\z/, "")
      end
    end

    def base64url(value)
      Base64.strict_encode64(value).tr("+/", "-_").delete("=")
    end

    def raw_signature(der_signature)
      OpenSSL::ASN1.decode(der_signature).value.map do |integer|
        hex = integer.value.to_i.to_s(16)
        hex = "0#{hex}" if hex.length.odd?
        [hex].pack("H*").rjust(32, "\x00")[-32, 32]
      end.join
    end
  end

  class APIClient
    BASE_URL = "https://api.appstoreconnect.apple.com"

    def initialize(credentials:, transport: Net::HTTP)
      @credentials = credentials
      @transport = transport
    end

    def get(path, query = {})
      request(:get, path, query: query)
    end

    def post(path, body)
      request(:post, path, body: body)
    end

    def patch(path, body)
      request(:patch, path, body: body)
    end

    private

    def request(method, path, query: {}, body: nil)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(query) unless query.empty?
      request = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method).new(uri)
      request["Authorization"] = "Bearer #{@credentials.token}"
      if body
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end
      response = @transport.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
      parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return parsed if response.is_a?(Net::HTTPSuccess)
      detail = parsed.fetch("errors", []).map { |item| item["detail"] || item["title"] }.compact.join("; ")
      raise APIError, "App Store Connect HTTP #{response.code}#{detail.empty? ? '' : ": #{detail}"}"
    rescue JSON::ParserError => error
      raise APIError, "App Store Connect returned invalid JSON: #{error.message}"
    rescue SocketError, SystemCallError, Timeout::Error => error
      raise APIError, "App Store Connect request failed: #{error.message}"
    end
  end

  class StateStore
    def initialize(directory: ENV.fetch("FORZADVISOR_RELEASE_STATE_DIR", File.expand_path("~/.codex/state/forzadvisor-release")))
      @directory = File.expand_path(directory)
    end

    def active?
      File.file?(path)
    end
    def load
      raise Error, "no active release; run cloud-start first" unless active?
      JSON.parse(File.read(path))
    end
    def save(state)
      FileUtils.mkdir_p(@directory)
      tmp = "#{path}.#{Process.pid}.tmp"
      File.write(tmp, JSON.pretty_generate(state.merge("updated_at" => Time.now.utc.iso8601)) + "\n", perm: 0o600)
      File.rename(tmp, path)
      JSON.parse(File.read(path))
    ensure
      File.delete(tmp) if defined?(tmp) && File.file?(tmp)
    end
    def save_evidence(evidence)
      FileUtils.mkdir_p(@directory)
      temporary = "#{evidence_path}.#{Process.pid}.tmp"
      File.write(temporary, JSON.pretty_generate(evidence) + "\n", perm: 0o600)
      File.rename(temporary, evidence_path)
      evidence
    ensure
      File.delete(temporary) if defined?(temporary) && File.file?(temporary)
    end
    def archive(state)
      FileUtils.mkdir_p(File.join(@directory, "history"))
      stamp = Time.now.utc.strftime("%Y%m%dT%H%M%S.%6NZ")
      archive_path = File.join(@directory, "history", "#{stamp}-#{state.fetch('ref', 'unknown').gsub(/[^A-Za-z0-9_.-]/, '_')}.json")
      temporary = "#{archive_path}.#{Process.pid}.tmp"
      File.write(temporary, JSON.pretty_generate(state) + "\n", perm: 0o600)
      File.rename(temporary, archive_path)
      archive_path
    ensure
      File.delete(temporary) if defined?(temporary) && File.file?(temporary)
    end
    private
    def path
      File.join(@directory, "active.json")
    end
    def evidence_path
      File.join(@directory, "app-store-preflight.json")
    end
  end

  class CloudCoordinator
    SUCCESS = %w[SUCCESS SUCCEEDED].freeze
    TERMINAL_PHASES = %w[verify_failed candidate_failed app_review_submitted submission_failed].freeze
    def initialize(config:, api:, git:, store:)
      @config, @api, @git, @store = config, api, git, store
    end
    def start(ref: nil)
      raise PreflightError, "cloud-start requires --ref RELEASE_TAG" if ref.to_s.empty?
      proof = @git.assert_release_state!(@config, ref: ref, require_tag: true)
      previous = @store.active? ? @store.load : nil
      if previous
        same_release = previous.values_at("commit", "ref") == proof.values_at("commit", "ref")
        return previous if same_release && previous["phase"] != "verify_start_intent"
        unless same_release
          raise PreflightError, "another release is active; finish it before starting #{proof.fetch('ref')}" unless TERMINAL_PHASES.include?(previous["phase"])
          @store.archive(previous)
          previous = nil
        end
      end
      reference = git_reference(proof)
      rechecked = @git.assert_release_state!(@config, ref: proof.fetch("ref"), require_tag: true)
      raise PreflightError, "release tag moved before Verify start" unless rechecked["peeled_tag_commit"] == proof["peeled_tag_commit"]
      evidence = { "source_build_number" => @config.fetch("release", "source_build_number"), "current_app_store_build_number" => @config.fetch("release", "current_app_store_build_number"), "marketing_version" => @config.fetch("release", "marketing_version"), "price" => @config.fetch("release", "price"), "privacy" => @config.fetch("release", "privacy"), "content_rights" => @config.fetch("release", "content_rights"), "submission_policy" => @config.fetch("release", "submission_policy"), "app_store_release_type" => @config.fetch("release", "app_store_release_type") }
      intent = previous || @store.save(proof.merge(evidence).merge("phase" => "verify_start_intent", "verify_start_intent_at" => Time.now.utc.iso8601, "verify_start_request" => { "workflow_id" => @config.fetch("xcode_cloud", "workflows", "verify", "id"), "reference_id" => reference.fetch("id"), "ref_kind" => "tag", "peeled_tag_commit" => proof.fetch("peeled_tag_commit"), "clean" => true }))
      run = start_run("verify", reference, proof.fetch("commit"), not_before: intent.fetch("verify_start_intent_at"), expected_reference_id: intent.dig("verify_start_request", "reference_id"))
      @store.save(intent.merge("phase" => "verify_running", "verify_run_id" => run.fetch("id")))
    end
    def status
      advance(@store.load, false)
    end
    def resume
      advance(@store.load, true)
    end
    private
    def advance(state, mutate)
      case state["phase"]
      when "candidate_start_intent" then start_candidate(state)
      when "verify_running"
        run = @api.get("/v1/ciBuildRuns/#{state.fetch('verify_run_id')}").fetch("data")
        return state unless run.dig("attributes", "executionProgress") == "COMPLETE"
        return @store.save(state.merge("phase" => "verify_failed")) unless SUCCESS.include?(run.dig("attributes", "completionStatus"))
        ensure_commit!(state, run)
        state = @store.save(state.merge("phase" => "verified"))
        mutate ? start_candidate(state) : state
      when "verified" then mutate ? start_candidate(state) : state
      when "candidate_running"
        run = @api.get("/v1/ciBuildRuns/#{state.fetch('candidate_run_id')}").fetch("data")
        return state unless run.dig("attributes", "executionProgress") == "COMPLETE"
        return @store.save(state.merge("phase" => "candidate_failed")) unless SUCCESS.include?(run.dig("attributes", "completionStatus"))
        ensure_commit!(state, run)
        builds = @api.get("/v1/ciBuildRuns/#{state.fetch('candidate_run_id')}/builds", "limit" => 50).fetch("data", [])
        candidates = builds.each_with_object([]) do |record, found|
          build = @api.get("/v1/builds/#{record.fetch('id')}").fetch("data")
          owner = @api.get("/v1/builds/#{record.fetch('id')}/app").fetch("data")
          prerelease = @api.get("/v1/builds/#{record.fetch('id')}/preReleaseVersion").fetch("data")
          found << build if owner["id"] == @config.fetch("app", "id") && prerelease.dig("attributes", "version") == @config.fetch("release", "marketing_version") && prerelease.dig("attributes", "platform") == "IOS"
        end
        raise APIError, "Release Candidate run produced multiple iOS builds for this app/version" if candidates.length > 1
        build = candidates.first
        return @store.save(state.merge("phase" => "build_processing")) unless build
        processing = build.dig("attributes", "processingState")
        return @store.save(state.merge("phase" => "candidate_failed", "build_id" => build["id"], "build_processing_state" => processing)) if %w[FAILED INVALID].include?(processing)
        phase = processing == "VALID" && build.dig("attributes", "buildAudienceType") == @config.fetch("release", "expected_build_audience") ? "candidate_ready" : "build_processing"
        @store.save(state.merge("phase" => phase, "build_id" => build["id"], "app_store_build_number" => build.dig("attributes", "version"), "build_processing_state" => build.dig("attributes", "processingState")))
      when "build_processing" then advance(state.merge("phase" => "candidate_running"), mutate)
      else state
      end
    end
    def start_candidate(state)
      current = @git.assert_release_state!(@config, ref: state.fetch("ref"), require_tag: true)
      raise PreflightError, "release ref moved after Verify" unless current["commit"] == state["commit"]
      reference = git_reference(state)
      immediate = @git.assert_release_state!(@config, ref: state.fetch("ref"), require_tag: true)
      raise PreflightError, "release tag moved before Release Candidate start" unless immediate["peeled_tag_commit"] == state["peeled_tag_commit"]
      intent = state["phase"] == "candidate_start_intent" ? state : @store.save(state.merge("phase" => "candidate_start_intent", "candidate_start_intent_at" => Time.now.utc.iso8601, "candidate_start_request" => { "workflow_id" => @config.fetch("xcode_cloud", "workflows", "release_candidate", "id"), "reference_id" => reference.fetch("id"), "ref_kind" => "tag", "peeled_tag_commit" => state.fetch("peeled_tag_commit"), "clean" => true }))
      run = start_run("release_candidate", reference, state.fetch("commit"), not_before: intent.fetch("candidate_start_intent_at"), expected_reference_id: intent.dig("candidate_start_request", "reference_id"))
      @store.save(intent.merge("phase" => "candidate_running", "candidate_run_id" => run.fetch("id")))
    end
    def git_reference(state)
      kind = state["ref_kind"] == "tag" ? "TAG" : "BRANCH"
      @api.get("/v1/scmRepositories/#{@config.fetch('xcode_cloud', 'repository_id')}/gitReferences", "limit" => 200).fetch("data").find { |item| item.dig("attributes", "kind") == kind && item.dig("attributes", "canonicalName") == "refs/#{state['ref_kind'] == 'tag' ? 'tags' : 'heads'}/#{state['ref']}" } || raise(APIError, "Xcode Cloud ref not found")
    end
    def start_run(key, reference, commit, not_before:, expected_reference_id:)
      raise APIError, "persisted Xcode Cloud start intent lacks a tag reference" if expected_reference_id.to_s.empty?
      workflow = @config.fetch("xcode_cloud", "workflows", key, "id")
      matches = @api.get("/v1/ciWorkflows/#{workflow}/buildRuns", "limit" => 50).fetch("data", []).select do |run|
        source = run.dig("attributes", "sourceCommit")
        source = source["commitSha"] if source.is_a?(Hash)
        created = Time.iso8601(run.dig("attributes", "createdDate")) rescue Time.at(0)
        source == commit && created >= Time.iso8601(not_before) && run.dig("attributes", "startReason") == "MANUAL"
      end
      raise APIError, "multiple Xcode Cloud runs match persisted start intent" if matches.length > 1
      if matches.one?
        recovered = matches.first
        observed_reference = recovered.dig("relationships", "sourceBranchOrTag", "data", "id") || recovered.dig("attributes", "sourceBranchOrTag", "id")
        observed_clean = recovered.dig("attributes", "clean")
        unless observed_reference == expected_reference_id && observed_clean == true
          raise APIError, "cannot safely reconcile Xcode Cloud run: tag reference or clean-build evidence is unavailable"
        end
        return recovered
      end
      @api.post("/v1/ciBuildRuns", { data: { type: "ciBuildRuns", attributes: { clean: true }, relationships: { workflow: { data: { type: "ciWorkflows", id: workflow } }, sourceBranchOrTag: { data: { type: "scmGitReferences", id: reference.fetch("id") } } } } }).fetch("data")
    end
    def ensure_commit!(state, run)
      source = run.dig("attributes", "sourceCommit")
      source = source["commitSha"] if source.is_a?(Hash)
      raise APIError, "Xcode Cloud run used a different source commit" unless source == state["commit"]
    end
  end

  class CandidateStager
    def initialize(config:, api:, checkpoint: nil)
      @config, @api, @checkpoint = config, api, checkpoint || proc { |_event, _evidence| }
    end
    def call(build_id:)
      app = @config.fetch("app", "id")
      group = @config.fetch("testflight", "internal_group", "id")
      versions = @api.get("/v1/apps/#{app}/appStoreVersions", "filter[platform]" => "IOS", "filter[versionString]" => @config.fetch("release", "marketing_version"), "limit" => 10).fetch("data", [])
      raise APIError, "configured App Store version was not uniquely observed" unless versions.length == 1 && versions.first["id"] == @config.fetch("app_store", "version_id")
      version = versions.first
      candidate = @api.get("/v1/builds/#{build_id}").fetch("data")
      owner = @api.get("/v1/builds/#{build_id}/app").fetch("data")
      unless owner["id"] == app && candidate.dig("attributes", "processingState") == "VALID" && candidate.dig("attributes", "buildAudienceType") == @config.fetch("release", "expected_build_audience")
        raise APIError, "candidate build identity or eligibility changed before staging"
      end
      submissions = @api.get("/v1/apps/#{app}/reviewSubmissions", "limit" => 20).fetch("data", [])
      configured_submission = @config.fetch("app_store", "review_submission_id")
      submission = submissions.find { |item| item["id"] == configured_submission && item.dig("attributes", "platform") == "IOS" && item.dig("attributes", "state") == "READY_FOR_REVIEW" }
      raise APIError, "configured iOS review draft was not observed" unless submission
      items = @api.get("/v1/reviewSubmissions/#{submission['id']}/items", "limit" => 50).fetch("data", [])
      item_targets_version = proc do |item|
        related = item.dig("relationships", "appStoreVersion", "data", "id")
        item["id"] == @config.fetch("app_store", "review_submission_item_id") &&
          (related == version["id"] || (related.nil? && version["id"] == @config.fetch("app_store", "version_id")))
      end
      raise APIError, "review draft is mixed or does not contain the configured item" unless items.length == 1 && item_targets_version.call(items.first)
      attached = @api.get("/v1/appStoreVersions/#{version['id']}/build").fetch("data", nil)
      if attached && attached["id"] != build_id && attached.dig("attributes", "version") != @config.fetch("release", "current_app_store_build_number")
        raise APIError, "selected build is neither the configured baseline nor the cloud candidate"
      end
      group_builds = @api.get("/v1/betaGroups/#{group}/builds", "limit" => 200).fetch("data", [])
      unless group_builds.any? { |item| item["id"] == build_id }
        @checkpoint.call("testflight_attach_intent", { "build_id" => build_id, "group_id" => group })
        @api.post("/v1/betaGroups/#{group}/relationships/builds", { data: [{ type: "builds", id: build_id }] })
        observed = @api.get("/v1/betaGroups/#{group}/builds", "limit" => 200).fetch("data", [])
        raise APIError, "TestFlight build attachment was not observed" unless observed.any? { |item| item["id"] == build_id }
        @checkpoint.call("testflight_attached", { "build_id" => build_id, "group_id" => group })
      end
      if attached&.fetch("id", nil) != build_id
        @checkpoint.call("build_attach_intent", { "build_id" => build_id, "version_id" => version["id"] })
        @api.patch("/v1/appStoreVersions/#{version['id']}/relationships/build", { data: { type: "builds", id: build_id } })
        observed = @api.get("/v1/appStoreVersions/#{version['id']}/build").fetch("data", nil)
        raise APIError, "App Store build attachment was not observed" unless observed&.fetch("id", nil) == build_id
        @checkpoint.call("build_attached", { "build_id" => build_id, "version_id" => version["id"] })
      end
      { "phase" => "staged", "version_id" => version["id"], "build_id" => build_id, "review_submission_id" => submission["id"] }
    end
    def submit(submission_id:, submit:, acknowledge:)
      SubmissionGuard.authorize!(submit: submit, acknowledge_irreversible_app_review_submission: acknowledge)
      current = @api.get("/v1/reviewSubmissions/#{submission_id}").fetch("data")
      current_state = current.dig("attributes", "state")
      return { "phase" => "app_review_submitted", "review_submission_id" => submission_id, "submission_state" => current_state } if %w[WAITING_FOR_REVIEW IN_REVIEW ACCEPTED PENDING_APPLE_RELEASE PROCESSING_FOR_DISTRIBUTION READY_FOR_SALE].include?(current_state)
      return { "phase" => "submission_failed", "review_submission_id" => submission_id, "submission_state" => current_state } if %w[CANCELED REJECTED FAILED].include?(current_state)
      raise PreflightError, "review submission is not in READY_FOR_REVIEW; refusing PATCH from #{current_state || 'unknown'}" unless current_state == "READY_FOR_REVIEW"
      @checkpoint.call("submission_intent", { "review_submission_id" => submission_id })
      @api.patch("/v1/reviewSubmissions/#{submission_id}", { data: { type: "reviewSubmissions", id: submission_id, attributes: { submitted: true } } })
      observed = @api.get("/v1/reviewSubmissions/#{submission_id}").fetch("data")
      state = observed.dig("attributes", "state")
      raise APIError, "App Review submission was not observed" unless %w[WAITING_FOR_REVIEW IN_REVIEW ACCEPTED].include?(state)
      @checkpoint.call("app_review_submitted", { "review_submission_id" => submission_id, "submission_state" => state })
      { "phase" => "app_review_submitted", "review_submission_id" => submission_id, "submission_state" => state }
    end
  end

  class AppStoreStatus
    def initialize(config:, api:)
      @config = config
      @api = api
    end

    def call
      app_id = @config.fetch("app", "id")
      app = @api.get("/v1/apps/#{app_id}").fetch("data")
      unless app.dig("attributes", "name") == @config.fetch("app", "name") && app.dig("attributes", "bundleId") == @config.fetch("app", "bundle_id")
        raise APIError, "App Store Connect identity does not match release config"
      end
      versions = @api.get("/v1/apps/#{app_id}/appStoreVersions", "filter[platform]" => "IOS", "filter[versionString]" => @config.fetch("release", "marketing_version"), "limit" => 10).fetch("data", [])
      version = versions.first
      # The app-builds relationship does not accept filter[version]. Fetch the
      # newest bounded page and select the configured build number locally.
      builds = @api.get("/v1/apps/#{app_id}/builds", "limit" => 200).fetch("data", [])
      build = builds.find { |item| item.dig("attributes", "version") == @config.fetch("release", "current_app_store_build_number") }
      submissions = @api.get("/v1/apps/#{app_id}/reviewSubmissions", "limit" => 20).fetch("data", [])
      {
        "app" => { "id" => app_id, "name" => app.dig("attributes", "name"), "bundle_id" => app.dig("attributes", "bundleId") },
        "marketing_version" => @config.fetch("release", "marketing_version"),
        "source_build_number" => @config.fetch("release", "source_build_number"),
        "current_app_store_build_number" => @config.fetch("release", "current_app_store_build_number"),
        "version" => version && { "id" => version["id"], "state" => version.dig("attributes", "appStoreState") },
        "build" => build && { "id" => build["id"], "number" => build.dig("attributes", "version"), "processing_state" => build.dig("attributes", "processingState") },
        "review_submissions" => submissions.map { |item| { "id" => item["id"], "state" => item.dig("attributes", "state") } },
        "read_only" => true
      }
    rescue KeyError => error
      raise APIError, "App Store Connect response is incomplete: #{error.message}"
    end
  end

  class AppStorePreflight
    READY_SUBMISSION_STATES = %w[DRAFT READY_FOR_REVIEW].freeze
    def initialize(config:, api:, today: Date.today)
      @config, @api, @today = config, api, today
    end
    def call(expected_build_id: nil, require_stageable: false, require_selected_build: false)
      app_id = @config.fetch("app", "id")
      app = @api.get("/v1/apps/#{app_id}").fetch("data")
      assert!(app.dig("attributes", "name") == @config.fetch("app", "name") && app.dig("attributes", "bundleId") == @config.fetch("app", "bundle_id"), "app identity mismatch")
      assert!(app.dig("attributes", "contentRightsDeclaration") == @config.fetch("release", "content_rights"), "content rights mismatch")
      versions = @api.get("/v1/apps/#{app_id}/appStoreVersions", "filter[platform]" => "IOS", "filter[versionString]" => @config.fetch("release", "marketing_version"), "limit" => 10).fetch("data", [])
      assert!(versions.length == 1, "expected exactly one iOS App Store version")
      assert!(versions.first["id"] == @config.fetch("app_store", "version_id"), "App Store version identity mismatch")
      version = @api.get("/v1/appStoreVersions/#{versions.first.fetch('id')}").fetch("data")
      assert!(version.dig("attributes", "versionString") == @config.fetch("release", "marketing_version"), "version mismatch")
      assert!(version.dig("attributes", "releaseType") == @config.fetch("release", "app_store_release_type"), "release type mismatch")
      assert!(%w[READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW PENDING_APPLE_RELEASE PROCESSING_FOR_DISTRIBUTION READY_FOR_SALE].include?(version.dig("attributes", "appStoreState")), "App Store version has not passed required-field validation")
      selected_build = @api.get("/v1/appStoreVersions/#{version.fetch('id')}/build").fetch("data", nil)
      build = expected_build_id ? @api.get("/v1/builds/#{expected_build_id}").fetch("data") : selected_build
      assert!(build, "candidate build is missing")
      assert!(build["id"] == expected_build_id, "candidate build identity mismatch") if expected_build_id
      assert!(selected_build && selected_build["id"] == expected_build_id, "selected build differs from cloud candidate") if require_selected_build
      if expected_build_id && selected_build && selected_build["id"] != expected_build_id
        assert!(selected_build.dig("attributes", "version") == @config.fetch("release", "current_app_store_build_number"), "selected build is neither the configured baseline nor the cloud candidate")
      end
      assert!(build.dig("attributes", "version") == @config.fetch("release", "current_app_store_build_number"), "current App Store build number mismatch") unless expected_build_id
      assert!(build.dig("attributes", "processingState") == "VALID", "selected build is not VALID")
      assert!(build.dig("attributes", "buildAudienceType") == @config.fetch("release", "expected_build_audience"), "selected build is not App Store eligible")
      assert!(build.dig("attributes", "usesNonExemptEncryption") == @config.fetch("release", "export_compliance", "uses_non_exempt_encryption"), "export compliance mismatch")
      owner = @api.get("/v1/builds/#{build.fetch('id')}/app").fetch("data")
      assert!(owner["id"] == app_id, "build belongs to another app")
      localizations = @api.get("/v1/appStoreVersions/#{version.fetch('id')}/appStoreVersionLocalizations", "limit" => 50).fetch("data", [])
      localization = localizations.find { |item| item.dig("attributes", "locale") == "en-US" }
      assert!(localization, "en-US localization is missing")
      attrs = localization.fetch("attributes")
      %w[description keywords promotionalText marketingUrl supportUrl].each { |key| assert!(!attrs[key].to_s.empty?, "localization #{key} is missing") }
      assert!(attrs["marketingUrl"] == @config.fetch("public_urls", "marketing") && attrs["supportUrl"] == @config.fetch("public_urls", "support"), "localization URLs mismatch")
      root = File.dirname(File.dirname(@config.path))
      local_metadata = MetadataInspector.sections(File.join(root, @config.fetch("metadata", "path")))
      { "Description" => "description", "Keywords" => "keywords", "Promotional Text" => "promotionalText" }.each do |section, key|
        assert!(attrs[key] == local_metadata.fetch(section), "localization #{key} differs from repository metadata")
      end
      sets = @api.get("/v1/appStoreVersionLocalizations/#{localization.fetch('id')}/appScreenshotSets", "limit" => 50).fetch("data", [])
      screenshots = sets.flat_map { |set| @api.get("/v1/appScreenshotSets/#{set.fetch('id')}/appScreenshots", "limit" => 200).fetch("data", []) }
      assert!(screenshots.map { |item| item.dig("attributes", "fileName") } == @config.fetch("screenshots", "ordered_files"), "App Store screenshot selection or order mismatch")
      assert!(screenshots.all? { |item| item.dig("attributes", "imageAsset", "width") == @config.fetch("screenshots", "width") && item.dig("attributes", "imageAsset", "height") == @config.fetch("screenshots", "height") }, "App Store screenshot dimensions mismatch")
      assert!(screenshots.all? { |item| item.dig("attributes", "assetDeliveryState", "state") == "COMPLETE" }, "App Store screenshot processing is incomplete")
      price_response = @api.get("/v1/appPriceSchedules/#{app_id}/manualPrices", "limit" => 200, "include" => "appPricePoint")
      prices = price_response.fetch("data", [])
      manual_price = prices.find { |item| item["id"] == @config.fetch("release", "price", "manual_price_id") }
      assert!(manual_price && manual_price.dig("attributes", "manual") == true, "configured manual price is missing")
      configured_price_point_id = @config.fetch("release", "price", "price_point_id")
      assert!(manual_price.dig("relationships", "appPricePoint", "data", "id") == configured_price_point_id, "manual price does not reference the configured Free price point")
      active_start = parse_price_date(manual_price.dig("attributes", "startDate"), "startDate")
      active_end = parse_price_date(manual_price.dig("attributes", "endDate"), "endDate")
      assert!((active_start.nil? || active_start <= @today) && (active_end.nil? || active_end >= @today), "configured manual price is not effective today")
      included_price_point = price_response.fetch("included", []).find { |item| item["type"] == "appPricePoints" && item["id"] == configured_price_point_id }
      assert!(included_price_point && included_price_point.dig("attributes", "customerPrice") == @config.fetch("release", "price", "amount"), "manual price's included price point is not Free")
      price_points = @api.get("/v1/apps/#{app_id}/appPricePoints", "filter[territory]" => @config.fetch("release", "price", "base_territory"), "limit" => 200).fetch("data", [])
      free_point = price_points.find { |item| item["id"] == configured_price_point_id }
      assert!(free_point && free_point.dig("attributes", "customerPrice") == @config.fetch("release", "price", "amount"), "Free price point amount mismatch")
      base_territory = @api.get("/v1/appPriceSchedules/#{app_id}/baseTerritory").fetch("data")
      assert!(base_territory["id"] == @config.fetch("release", "price", "base_territory"), "price base territory mismatch")
      infos = @api.get("/v1/apps/#{app_id}/appInfos", "limit" => 50).fetch("data", [])
      info = infos.find { |item| item.dig("attributes", "appStoreAgeRating") == @config.fetch("release", "age_rating", "expected_app_store_rating") }
      assert!(info, "age rating mismatch")
      info_localizations = @api.get("/v1/appInfos/#{info.fetch('id')}/appInfoLocalizations", "limit" => 50).fetch("data", [])
      info_en = info_localizations.find { |item| item.dig("attributes", "locale") == "en-US" }
      assert!(info_en, "en-US app information localization is missing")
      info_attrs = info_en.fetch("attributes")
      assert!(info_attrs["name"] == local_metadata.fetch("App Name"), "App Store name differs from repository metadata")
      assert!(info_attrs["subtitle"] == local_metadata.fetch("Subtitle"), "App Store subtitle differs from repository metadata")
      assert!(info_attrs["privacyPolicyUrl"] == @config.fetch("public_urls", "privacy") && local_metadata.fetch("Privacy Policy").include?(info_attrs["privacyPolicyUrl"]), "privacy policy URL mismatch")
      assert!(info_attrs["privacyChoicesUrl"] == @config.fetch("public_urls", "privacy"), "privacy choices URL mismatch")
      review = @api.get("/v1/appStoreVersions/#{version.fetch('id')}/appStoreReviewDetail").fetch("data").fetch("attributes")
      %w[contactFirstName contactLastName contactPhone contactEmail notes].each { |key| assert!(!review[key].to_s.empty?, "review detail #{key} is missing") }
      assert!(review["notes"] == local_metadata.fetch("App Review Notes"), "App Review notes differ from repository metadata")
      assert!(@config.fetch("release", "privacy", "published_in_app_store_connect") == true && DatePattern.valid?(@config.fetch("release", "privacy", "human_attestation_date")), "privacy publication attestation is invalid")
      submissions = @api.get("/v1/apps/#{app_id}/reviewSubmissions", "limit" => 20).fetch("data", [])
      draft = submissions.find { |item| item["id"] == @config.fetch("app_store", "review_submission_id") && item.dig("attributes", "platform") == "IOS" && READY_SUBMISSION_STATES.include?(item.dig("attributes", "state")) }
      items = draft ? @api.get("/v1/reviewSubmissions/#{draft.fetch('id')}/items", "limit" => 50).fetch("data", []) : []
      matching_item = items.any? do |item|
        related = item.dig("relationships", "appStoreVersion", "data", "id")
        item["id"] == @config.fetch("app_store", "review_submission_item_id") &&
          (related == version["id"] || (related.nil? && item.dig("attributes", "state") == "READY_FOR_REVIEW"))
      end
      assert!(!draft || items.empty? || (items.length == 1 && matching_item), "review draft is mixed or targets a different version")
      if require_stageable
        assert!(version.dig("attributes", "appStoreState") == "READY_FOR_REVIEW", "version is not stageable")
        assert!(draft && draft.dig("attributes", "state") == "READY_FOR_REVIEW" && items.length == 1 && matching_item, "review draft is not stageable")
      end
      { "schema_version" => 1, "checked_at" => Time.now.utc.iso8601, "app_id" => app_id, "version_id" => version["id"], "version_state" => version.dig("attributes", "appStoreState"), "build_id" => build["id"], "app_store_build_number" => build.dig("attributes", "version"), "build_processing_state" => "VALID", "build_audience" => build.dig("attributes", "buildAudienceType"), "localization_id" => localization["id"], "screenshot_count" => screenshots.length, "price_model" => "FREE", "manual_price_id" => manual_price["id"], "price_point_id" => configured_price_point_id, "price_effective_on" => @today.iso8601, "privacy_attested_on" => @config.fetch("release", "privacy", "human_attestation_date"), "content_rights" => app.dig("attributes", "contentRightsDeclaration"), "age_rating" => @config.fetch("release", "age_rating", "expected_app_store_rating"), "review_contact_complete" => true, "uses_non_exempt_encryption" => build.dig("attributes", "usesNonExemptEncryption"), "release_type" => version.dig("attributes", "releaseType"), "review_submission_id" => draft&.fetch("id", nil), "ready" => true }
    end
    private
    def parse_price_date(value, field)
      return nil if value.nil?
      Date.iso8601(value)
    rescue Date::Error
      raise PreflightError, "App Store preflight: manual price #{field} is invalid"
    end
    def assert!(condition, message)
      raise PreflightError, "App Store preflight: #{message}" unless condition
    end
  end

  module Reporter
    module_function

    def text(result)
      if result["app_id"] && result.key?("ready")
        ["App Store preflight: #{result['ready'] ? 'PASS' : 'FAIL'}", "Version: #{result['version_id']}", "App Store build: #{result['app_store_build_number']} (#{result['build_processing_state']}, #{result['build_audience']})", "Screenshots: #{result['screenshot_count']}", "Review draft: #{result['review_submission_id'] || 'none'}"].join("\n")
      elsif result.key?("ready")
        lines = ["Release preflight: #{result['ready'] ? 'PASS' : 'FAIL'}"]
        result.fetch("checks", {}).each { |name, check| lines << "#{check['passed'] ? 'PASS' : 'FAIL'} #{name}" }
        lines.join("\n")
      else
        [
          "App Store Connect status (read-only)",
          "Version: #{result['marketing_version']} (#{result.dig('version', 'state') || 'not found'})",
          "Source build: #{result['source_build_number']}",
          "App Store build: #{result.dig('build', 'number') || 'not found'} (#{result.dig('build', 'processing_state') || 'unknown'})",
          "Review: #{result.fetch('review_submissions', []).map { |item| item['state'] }.join(', ')}"
        ].join("\n")
      end
    end
  end
end
