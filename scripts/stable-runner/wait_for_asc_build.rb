#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "uri"

module AppleRelease
  class Error < StandardError; end

  class JWTProvider
    def call
      key_id = ENV.fetch("ASC_KEY_ID")
      issuer_id = ENV.fetch("ASC_ISSUER_ID")
      key_path = ENV.fetch("ASC_KEY_PATH")
      header = encode(alg: "ES256", kid: key_id, typ: "JWT")
      now = Time.now.to_i
      payload = encode(iss: issuer_id, iat: now, exp: now + 900, aud: "appstoreconnect-v1")
      input = "#{header}.#{payload}"
      key = OpenSSL::PKey.read(File.read(key_path))
      sequence = OpenSSL::ASN1.decode(key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input)))
      signature = sequence.value.map { |integer| integer.value.to_s(2).rjust(32, "\0") }.join
      "#{input}.#{Base64.urlsafe_encode64(signature, padding: false)}"
    rescue KeyError, SystemCallError, OpenSSL::OpenSSLError, ArgumentError
      raise Error, "App Store Connect authentication is unavailable"
    end

    private

    def encode(value)
      Base64.urlsafe_encode64(value.to_json, padding: false)
    end
  end

  class ASCClient
    API_ROOT = "https://api.appstoreconnect.apple.com"

    def initialize(token_provider: JWTProvider.new)
      @token_provider = token_provider
    end

    def builds(app_id:, build:)
      query = URI.encode_www_form(
        "filter[app]" => app_id,
        "filter[version]" => build,
        "limit" => 100,
        "include" => "preReleaseVersion"
      )
      uri = URI("#{API_ROOT}/v1/builds?#{query}")
      request = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@token_provider.call}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
      raise Error, "App Store Connect request failed with HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "App Store Connect returned invalid JSON"
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError
      raise Error, "App Store Connect request failed"
    end
  end

  class BuildWaiter
    TERMINAL_FAILURES = %w[FAILED INVALID].freeze

    def initialize(client:, timeout: 1_800, interval: 20, clock: -> { Time.now }, sleeper: ->(seconds) { Kernel.sleep(seconds) })
      @client = client
      @timeout = timeout
      @interval = interval
      @clock = clock
      @sleeper = sleeper
      raise Error, "timeout must be nonnegative" unless timeout.is_a?(Integer) && timeout >= 0
      raise Error, "interval must be positive" unless interval.is_a?(Integer) && interval.positive?
    end

    def call(app_id:, platform:, version:, build:, expect_absent: false)
      deadline = @clock.call + @timeout
      loop do
        match = exact_match(@client.builds(app_id: app_id, build: build), platform: platform, version: version, build: build)
        if expect_absent
          raise Error, "exact App Store Connect build already exists" if match

          return result(app_id, platform, version, build, nil, "ABSENT")
        end
        if match
          state = match.dig("attributes", "processingState")
          return result(app_id, platform, version, build, match.fetch("id"), state) if state == "VALID"
          raise Error, "exact App Store Connect build was rejected with state #{state}" if TERMINAL_FAILURES.include?(state)
        end
        raise Error, "timed out waiting for exact App Store Connect build" if @clock.call >= deadline

        @sleeper.call(@interval)
      end
    end

    private

    def exact_match(response, platform:, version:, build:)
      prereleases = response.fetch("included", []).to_h { |entry| [entry.fetch("id"), entry.fetch("attributes")] }
      matches = response.fetch("data").select do |entry|
        prerelease = prereleases[entry.dig("relationships", "preReleaseVersion", "data", "id")]
        prerelease && prerelease["platform"] == platform && prerelease["version"] == version && entry.dig("attributes", "version") == build
      end
      raise Error, "multiple exact App Store Connect builds matched" if matches.length > 1

      matches.first
    rescue KeyError
      raise Error, "App Store Connect build response was incomplete"
    end

    def result(app_id, platform, version, build, build_id, state)
      {
        "app_id" => app_id,
        "platform" => platform,
        "marketing_version" => version,
        "build" => build,
        "build_id" => build_id,
        "state" => state
      }
    end
  end

  module CLI
    module_function

    def run(argv)
      options = { timeout: 1_800, interval: 20, json: false, expect_absent: false }
      OptionParser.new do |parser|
        parser.on("--app-id ID") { |value| options[:app_id] = value }
        parser.on("--platform PLATFORM") { |value| options[:platform] = value }
        parser.on("--version VERSION") { |value| options[:version] = value }
        parser.on("--build BUILD") { |value| options[:build] = value }
        parser.on("--timeout SECONDS", Integer) { |value| options[:timeout] = value }
        parser.on("--interval SECONDS", Integer) { |value| options[:interval] = value }
        parser.on("--expect-absent") { options[:expect_absent] = true }
        parser.on("--json") { options[:json] = true }
      end.parse!(argv)
      %i[app_id platform version build].each do |key|
        raise Error, "--#{key.to_s.tr('_', '-')} is required" if options[key].to_s.empty?
      end
      raise Error, "platform must be IOS or MAC_OS" unless %w[IOS MAC_OS].include?(options[:platform])

      result = BuildWaiter.new(
        client: ASCClient.new,
        timeout: options[:timeout],
        interval: options[:interval]
      ).call(
        app_id: options[:app_id],
        platform: options[:platform],
        version: options[:version],
        build: options[:build],
        expect_absent: options[:expect_absent]
      )
      if options[:json]
        puts JSON.generate(result)
      else
        puts "App Store Connect build #{result['platform']} #{result['marketing_version']} (#{result['build']}): #{result['state']}"
      end
      0
    rescue Error, OptionParser::ParseError => error
      warn "wait_for_asc_build: #{error.message}"
      1
    end
  end
end

exit AppleRelease::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
