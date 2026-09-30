#
#  Rake tasks to manage native gem packages with binary executables from Pagefind/pagefind
#
#  TL;DR: run "rake package"
#
#  The native platform gems (defined by Pagefind::Upstream::NATIVE_PLATFORMS) will each contain
#  the pagefind_extended binary executable in addition to what the vanilla ruby gem contains:
#
#     exe/
#     ├── pagefind                             #  generic ruby script to find and run the binary
#     └── <Gem::Platform architecture name>/
#         └── pagefind_extended                #  the pagefind_extended binary executable
#
#  The ruby script `exe/pagefind` is installed into the user's path, and it simply locates the
#  binary and executes it. Note that this script is required because rubygems requires that
#  executables declared in a gemspec must be Ruby scripts.
#
#  As a concrete example, an x86_64-linux system will see these files on disk after installing
#  pagefind-1.x.x-x86_64-linux.gem:
#
#     exe/
#     ├── pagefind
#     └── x86_64-linux/
#         └── pagefind_extended
#
#  So the full set of gem files created will be:
#
#  - pkg/pagefind-1.0.0.gem
#  - pkg/pagefind-1.0.0-aarch64-linux.gem
#  - pkg/pagefind-1.0.0-aarch64-mingw-ucrt.gem
#  - pkg/pagefind-1.0.0-amd64-freebsd.gem
#  - pkg/pagefind-1.0.0-arm64-darwin.gem
#  - pkg/pagefind-1.0.0-x64-mingw-ucrt.gem
#  - pkg/pagefind-1.0.0-x86_64-darwin.gem
#  - pkg/pagefind-1.0.0-x86_64-linux.gem
#
#  Note that in addition to the native gems, a vanilla "ruby" gem will also be created with the
#  `exe/pagefind` script but without a binary executable present.
#
#
#  New rake tasks created:
#
#  - rake gem:ruby               # Build the ruby gem
#  - rake gem:aarch64-linux      # Build the aarch64-linux gem
#  - rake gem:aarch64-mingw-ucrt # Build the aarch64-mingw-ucrt gem
#  - rake gem:amd64-freebsd      # Build the amd64-freebsd gem
#  - rake gem:arm64-darwin       # Build the arm64-darwin gem
#  - rake gem:x64-mingw-ucrt     # Build the x64-mingw-ucrt gem
#  - rake gem:x86_64-darwin      # Build the x86_64-darwin gem
#  - rake gem:x86_64-linux       # Build the x86_64-linux gem
#  - rake download               # Download all pagefind binaries
#
#  Modified rake tasks:
#
#  - rake gem                    # Build all the gem files
#  - rake package                # Build all the gem files (same as `gem`)
#  - rake repackage              # Force a rebuild of all the gem files
#  - rake test                   # Run the tests (downloads the current platform's binary first)
#
#  Note also that the binary executables will be lazily downloaded when needed, but you can
#  explicitly download them with the `rake download` command.
#
require "rubygems/package_task"
require "rubygems/package"
require "open-uri"
require "digest"
require "zlib"
require_relative "../lib/pagefind/upstream"

PAGEFIND_ARCHIVE_DIR = "tmp"

def pagefind_archive_filename(target)
  "pagefind_extended-#{Pagefind::Upstream::VERSION}-#{target}.tar.gz"
end

def pagefind_download_url(filename)
  "https://github.com/Pagefind/pagefind/releases/download/#{Pagefind::Upstream::VERSION}/#{filename}"
end

PAGEFIND_RUBY_GEMSPEC = Bundler.load_gemspec("pagefind.gemspec")

# prepend the download task before the Gem::PackageTask tasks
task package: :download

gem_path = Gem::PackageTask.new(PAGEFIND_RUBY_GEMSPEC).define
desc "Build the ruby gem"
task "gem:ruby" => [gem_path]

directory PAGEFIND_ARCHIVE_DIR
archivepaths = Pagefind::Upstream::NATIVE_PLATFORMS.values.map do |target|
  archivepath = File.join(PAGEFIND_ARCHIVE_DIR, pagefind_archive_filename(target))

  file archivepath => [PAGEFIND_ARCHIVE_DIR] do
    release_url = pagefind_download_url(File.basename(archivepath))
    warn "Downloading #{archivepath} from #{release_url} ..."

    # lazy, but fine for now.
    URI.open(release_url) do |remote| # standard:disable Security/Open
      File.binwrite(archivepath, remote.read)
    end
  end

  archivepath
end

exepaths = []
Pagefind::Upstream::NATIVE_PLATFORMS.each do |platform, target|
  PAGEFIND_RUBY_GEMSPEC.dup.tap do |gemspec|
    exedir = File.join(gemspec.bindir, platform) # "exe/x86_64-linux"
    exepath = File.join(exedir, "pagefind_extended") # "exe/x86_64-linux/pagefind_extended"
    archivepath = File.join(PAGEFIND_ARCHIVE_DIR, pagefind_archive_filename(target)) # "tmp/pagefind_extended-v1.5.2-x86_64-unknown-linux-musl.tar.gz"
    exepaths << exepath

    # modify a copy of the gemspec to include the native executable
    gemspec.platform = platform
    gemspec.files += [exepath, "LICENSE-DEPENDENCIES"]

    # create a package task
    gem_path = Gem::PackageTask.new(gemspec).define
    desc "Build the #{platform} gem"
    task "gem:#{platform}" => [gem_path]

    directory exedir
    file exepath => [exedir, archivepath] do
      warn "Extracting #{exepath} from #{archivepath} ..."

      Zlib::GzipReader.open(archivepath) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          entry = tar.find { |entry| %w[pagefind_extended pagefind_extended.exe].include?(entry.full_name) }
          abort "Cannot find the pagefind executable in #{archivepath}" unless entry

          File.binwrite(exepath, entry.read)
        end
      end

      FileUtils.chmod(0o755, exepath, verbose: true)
    end
  end
end

desc "Validate checksums for pagefind archives"
task "check" => archivepaths do
  archivepaths.each do |archivepath|
    sha_url = pagefind_download_url("#{File.basename(archivepath)}.sha256")

    local_sha256 = Digest::SHA256.file(archivepath).hexdigest
    remote_sha256 = URI.open(sha_url).read.split.first # standard:disable Security/Open

    if local_sha256 == remote_sha256
      puts "Checksum OK for #{archivepath} (#{local_sha256})"
    else
      abort "Checksum mismatch for #{archivepath} (#{local_sha256} != #{remote_sha256})"
    end
  end
end

desc "Download all pagefind binaries"
task "download" => [:check, *exepaths]

local_exepath = exepaths.find do |exepath|
  Gem::Platform.match_gem?(Gem::Platform.new(File.basename(File.dirname(exepath))), PAGEFIND_RUBY_GEMSPEC.name)
end
task test: local_exepath if local_exepath

CLOBBER.add(exepaths.map { |p| File.dirname(p) })
CLOBBER.add(archivepaths)
