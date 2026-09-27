module Pagefind
  module Upstream
    VERSION = "v4.3.3"

    # rubygems platform name => upstream release filename
    NATIVE_PLATFORMS = {
      "arm64-darwin" => "pagefind-macos-arm64",
      "x64-mingw-ucrt" => "pagefind-windows-x64.exe",
      "x86_64-darwin" => "pagefind-macos-x64",
      "x86_64-linux-gnu" => "pagefind-linux-x64",
      "x86_64-linux-musl" => "pagefind-linux-x64-musl",
      "aarch64-linux-gnu" => "pagefind-linux-arm64",
      "aarch64-linux-musl" => "pagefind-linux-arm64-musl",
    }
  end
end
