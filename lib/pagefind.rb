# frozen_string_literal: true

require_relative "pagefind/version"
require_relative "pagefind/upstream"

module Pagefind
  DEFAULT_DIR = File.expand_path(File.join(__dir__, "..", "exe"))
  GEM_NAME = "pagefind-ruby"

  # raised when the host platform is not supported by upstream pagefind's binary releases
  class UnsupportedPlatformException < StandardError
  end

  # raised when the pagefind executable could not be found where we expected it to be
  class ExecutableNotFoundException < StandardError
  end

  # raised when PAGEFIND_INSTALL_DIR does not exist
  class DirectoryNotFoundException < StandardError
  end

  class << self
    def platform
      [:cpu, :os].map { |m| Gem::Platform.local.send(m) }.join("-")
    end

    def executable(exe_path: DEFAULT_DIR)
      pagefind_install_dir = ENV["PAGEFIND_INSTALL_DIR"]
      if pagefind_install_dir
        if File.directory?(pagefind_install_dir)
          warn "NOTE: using PAGEFIND_INSTALL_DIR to find pagefind executable: #{pagefind_install_dir}"
          exe_path = pagefind_install_dir
          exe_file = File.expand_path(File.join(pagefind_install_dir, "pagefind"))
        else
          raise DirectoryNotFoundException, <<~MESSAGE
            PAGEFIND_INSTALL_DIR is set to #{pagefind_install_dir}, but that directory does not exist.
          MESSAGE
        end
      else
        if Pagefind::Upstream::NATIVE_PLATFORMS.keys.none? { |p| Gem::Platform.match_gem?(Gem::Platform.new(p), GEM_NAME) }
          raise UnsupportedPlatformException, <<~MESSAGE
            #{GEM_NAME} does not support the #{platform} platform
            See https://github.com/bangseongbeom/pagefind-ruby#using-a-local-installation-of-pagefind
            for more details.
          MESSAGE
        end

        exe_file = Dir.glob(File.expand_path(File.join(exe_path, "*", "pagefind"))).find do |f|
          Gem::Platform.match_gem?(Gem::Platform.new(File.basename(File.dirname(f))), GEM_NAME)
        end
      end

      if exe_file.nil? || !File.exist?(exe_file)
        raise ExecutableNotFoundException, <<~MESSAGE
          Cannot find the pagefind executable for #{platform} in #{exe_path}

          If you're using bundler, please make sure you're on the latest bundler version:

              gem install bundler
              bundle update --bundler

          Then make sure your lock file includes this platform by running:

              bundle lock --add-platform #{platform}
              bundle install

          See `bundle lock --help` output for details.

          If you're still seeing this message after taking those steps, try running
          `bundle config` and ensure `force_ruby_platform` isn't set to `true`. See
          https://github.com/bangseongbeom/pagefind-ruby#check-bundle_force_ruby_platform
          for more details.
        MESSAGE
      end

      exe_file
    end
  end
end
