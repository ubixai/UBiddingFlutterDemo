# Optional host-side Podfile helper. No SDK binary is bundled with the plugin.
require 'uri'

module UbiddingSdkConfig
  VERSION = '4.1.2.13'.freeze
  CDN = 'https://cdn.cocoapods.org/'.freeze

  def self.sources(podfile, env = ENV)
    source = env.fetch('UBIDDING_POD_SOURCE', '').strip
    unless source.empty?
      begin
        uri = URI.parse(source)
        valid = %w[https http ssh git].include?(uri.scheme) && !uri.host.to_s.empty?
      rescue URI::InvalidURIError
        valid = false
      end
      unless valid
        raise Pod::Informative, 'sdk_source_invalid: UBIDDING_POD_SOURCE must be a spec repository URL; use UBIDDING_IOS_SDK_PATH for a local SDK.'
      end
      podfile.source(source) unless source == CDN
    end
    # Preserve public transitive dependencies when adding a private SDK source.
    podfile.source(CDN)
  end

  def self.local_sdk(podfile, env = ENV, base = Dir.pwd)
    configured = env.fetch('UBIDDING_IOS_SDK_PATH', '').strip
    return if configured.empty?

    directory = File.expand_path(configured, base)
    unless File.directory?(directory)
      raise Pod::Informative, 'sdk_directory_invalid: UBIDDING_IOS_SDK_PATH must identify the directory containing UBiddingAdSDK.podspec.'
    end
    candidates = %w[UBiddingAdSDK.podspec UBiddingAdSDK.podspec.json].map { |name| File.join(directory, name) }.select { |path| File.file?(path) }
    unless candidates.length == 1
      raise Pod::Informative, 'sdk_podspec_missing: Provide exactly one UBiddingAdSDK.podspec or UBiddingAdSDK.podspec.json.'
    end
    specification = Pod::Specification.from_file(candidates.first)
    unless specification.name == 'UBiddingAdSDK'
      raise Pod::Informative, 'sdk_name_mismatch: The host Pod must be named UBiddingAdSDK.'
    end
    unless specification.version.to_s == VERSION
      raise Pod::Informative, 'sdk_version_mismatch: The host Pod must declare UBiddingAdSDK 4.1.2.13.'
    end
    # The plugin keeps its exact dependency, so SDK headers reach the plugin target.
    podfile.pod('UBiddingAdSDK', :path => directory)
  end
end
