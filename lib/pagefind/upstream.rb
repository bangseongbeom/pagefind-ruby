module Pagefind
  module Upstream
    VERSION = "v1.5.2"

    # rubygems platform name => upstream release target
    NATIVE_PLATFORMS = {
      "arm64-darwin" => "aarch64-apple-darwin",
      "x86_64-darwin" => "x86_64-apple-darwin",
      "x64-mingw-ucrt" => "x86_64-pc-windows-msvc",
      "aarch64-mingw-ucrt" => "aarch64-pc-windows-msvc",
      "x86_64-linux" => "x86_64-unknown-linux-musl",
      "aarch64-linux" => "aarch64-unknown-linux-musl",
      "amd64-freebsd" => "x86_64-unknown-freebsd"
    }
  end
end
