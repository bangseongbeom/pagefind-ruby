# coding: utf-8
#
#  Rake tasks to manage native gem packages with binary executables from Pagefind/pagefind
#
#  TL;DR: run "rake package"
#
#  The native platform gems (defined by Pagefind::Upstream::NATIVE_PLATFORMS) will each contain
#  two files in addition to what the vanilla ruby gem contains:
#
#     exe/
#     ├── pagefind                             #  generic ruby script to find and run the binary
#     └── <Gem::Platform architecture name>/
#         └── pagefind                         #  the pagefind binary executable
#
#  The ruby script `exe/pagefind` is installed into the user's path, and it simply locates the
#  binary and executes it. Note that this script is required because rubygems requires that
#  executables declared in a gemspec must be Ruby scripts.
#
#  Windows support note: we ship the same executable in two gems, the `x64-mingw32` and
#  `x64-mingw-ucrt` flavors because Ruby < 3.1 uses the MSCVRT runtime libraries, and Ruby >= 3.1
#  uses the UCRT runtime libraries. You can read more about this change here:
#
#     https://rubyinstaller.org/2021/12/31/rubyinstaller-3.1.0-1-released.html
#
#  As a concrete example, an x86_64-linux system will see these files on disk after installing
#  pagefind-1.x.x-x86_64-linux.gem:
#
#     exe/
#     ├── pagefind
#     └── x86_64-linux/
#         └── pagefind
#
#  So the full set of gem files created will be:
#
#  - pkg/pagefind-1.0.0.gem
#  - pkg/pagefind-1.0.0-aarch64-linux.gem
#  - pkg/pagefind-1.0.0-arm64-darwin.gem
#  - pkg/pagefind-1.0.0-x64-mingw32.gem
#  - pkg/pagefind-1.0.0-x64-mingw-ucrt.gem
#  - pkg/pagefind-1.0.0-x86_64-darwin.gem
#  - pkg/pagefind-1.0.0-x86_64-linux.gem
# 
#  Note that in addition to the native gems, a vanilla "ruby" gem will also be created without
#  either the `exe/pagefind` script or a binary executable present.
#
#
#  New rake tasks created:
#
#  - rake gem:ruby           # Build the ruby gem
#  - rake gem:aarch64-linux  # Build the aarch64-linux gem
#  - rake gem:arm64-darwin   # Build the arm64-darwin gem
#  - rake gem:x64-mingw32    # Build the x64-mingw32 gem
#  - rake gem:x64-mingw-ucrt # Build the x64-mingw-ucrt gem
#  - rake gem:x86_64-darwin  # Build the x86_64-darwin gem
#  - rake gem:x86_64-linux   # Build the x86_64-linux gem
#  - rake download           # Download all pagefind binaries
#
#  Modified rake tasks:
#
#  - rake gem                # Build all the gem files
#  - rake package            # Build all the gem files (same as `gem`)
#  - rake repackage          # Force a rebuild of all the gem files
#
#  Note also that the binary executables will be lazily downloaded when needed, but you can
#  explicitly download them with the `rake download` command.
#
require "rubygems/package_task"
require "open-uri"
require_relative "../lib/pagefind/upstream"

def pagefind_download_url(filename)
  "https://github.com/Pagefind/pagefind/releases/download/#{Pagefind::Upstream::VERSION}/#{filename}"
end

PAGEFIND_RUBY_GEMSPEC = Bundler.load_gemspec("pagefind.gemspec")

# prepend the download task before the Gem::PackageTask tasks
task :package => :download

gem_path = Gem::PackageTask.new(PAGEFIND_RUBY_GEMSPEC).define
desc "Build the ruby gem"
task "gem:ruby" => [gem_path]

exepaths = []
Pagefind::Upstream::NATIVE_PLATFORMS.each do |platform, filename|
  PAGEFIND_RUBY_GEMSPEC.dup.tap do |gemspec|
    exedir = File.join(gemspec.bindir, platform) # "exe/x86_64-linux"
    exepath = File.join(exedir, "pagefind") # "exe/x86_64-linux/pagefind"
    exepaths << exepath

    # modify a copy of the gemspec to include the native executable
    gemspec.platform = platform
    gemspec.files += [exepath, "LICENSE-DEPENDENCIES"]

    # create a package task
    gem_path = Gem::PackageTask.new(gemspec).define
    desc "Build the #{platform} gem"
    task "gem:#{platform}" => [gem_path]

    directory exedir
    file exepath => [exedir] do
      release_url = pagefind_download_url(filename)
      warn "Downloading #{exepath} from #{release_url} ..."

      # lazy, but fine for now.
      URI.open(release_url) do |remote|
        File.open(exepath, "wb") do |local|
          local.write(remote.read)
        end
      end
      FileUtils.chmod(0755, exepath, verbose: true)
    end
  end
end

desc "Validate checksums for pagefind binaries"
task "check" => exepaths do
  sha_filename = File.absolute_path("../package/pagefind-#{Pagefind::Upstream::VERSION}-checksums.txt", __dir__)
  sha_url = if File.exist?(sha_filename)
    sha_filename
  else
    sha_url = pagefind_download_url("sha256sums.txt")
  end
  gemspec = PAGEFIND_RUBY_GEMSPEC

  checksums = URI.open(sha_url).each_line.map do |line|
    checksum, file = line.split
    [File.basename(file), checksum]
  end.to_h

  Pagefind::Upstream::NATIVE_PLATFORMS.each do |platform, filename|
    exedir = File.join(gemspec.bindir, platform) # "exe/x86_64-linux"
    exepath = File.join(exedir, "pagefind") # "exe/x86_64-linux/pagefind"

    local_sha256 = Digest::SHA256.file(exepath).hexdigest
    remote_sha256 = checksums.fetch(filename)

    if local_sha256 == remote_sha256
      puts "Checksum OK for #{exepath} (#{local_sha256})"
    else
      abort "Checksum mismatch for #{exepath} (#{local_sha256} != #{remote_sha256})"
    end
  end
end

desc "Download all pagefind binaries"
task "download" => :check

CLOBBER.add(exepaths.map { |p| File.dirname(p) })
