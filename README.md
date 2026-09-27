# Pagefind

A self-contained `pagefind` executable, wrapped up in a ruby gem. That's it. Nothing else.


## Installation

This gem wraps [the precompiled binary](https://pagefind.app/docs/installation/#downloading-a-precompiled-binary) of Pagefind. These binaries are platform specific, so there are actually separate underlying gems per platform, but the correct gem will automatically be picked for your platform.

Supported platforms are:

- arm64-darwin (macos-arm64)
- x64-mingw32 (windows-x64)
- x64-mingw-ucr (windows-x64)
- x86_64-darwin (macos-x64)
- x86_64-linux (linux-x64)
- aarch64-linux (linux-arm64)
- arm-linux (linux-armv7)

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add pagefind
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install pagefind
```

### Using a local installation of `pagefind`

If you are not able to use the vendored standalone executables (for example, if you're on an unsupported platform), you can use a [local installation](https://pagefind.app/docs/installation) of the `pagefind` executable by setting an environment variable named `PAGEFIND_INSTALL_DIR` to the directory path containing the executable.

For example, if you've installed `pagefind` so that the executable is found at `/path/to/node_modules/bin/pagefind`, then you should set your environment variable like so:

``` sh
PAGEFIND_INSTALL_DIR=/path/to/node_modules/bin
```

or, for relative paths like `./node_modules/.bin/pagefind`:

``` sh
PAGEFIND_INSTALL_DIR=node_modules/.bin
```


## Versioning

This gem will always have the same version number as the underlying Pagefind release. For example, the gem with version v1.5.2 will package upstream Pagefind v1.5.2.

If there ever needs to be multiple releases for the same version of Pagefind, the version will contain an additional digit. For example, if we re-released Pagefind v1.5.2, it might be shipped in gem version v1.5.2.1 or v1.5.2.2.


## Usage

### Ruby

The gem makes available `Pagefind.executable` which is the path to the vendored standalone executable.

``` ruby
require "pagefind"
Pagefind.executable
# => "/path/to/installs/ruby/3.3.5/lib/ruby/gems/3.3.0/gems/pagefind-0.1.0-x86_64-linux/exe/x86_64-linux/pagefind"
```


### Command line

This gem provides an executable `pagefind` shim that will run the vendored standalone executable.

``` bash
# where is the shim?
$ bundle exec which pagefind
/path/to/installs/ruby/3.3/bin/pagefind

# run the actual executable through the shim
$ bundle exec pagefind --help
["/path/to/installs/installs/ruby/3.4.2/lib/ruby/gems/3.4.0/gems/pagefind-4.0.12-x86_64-linux-gnu/exe/x86_64-linux-gnu/pagefind", "--help"]
≈ pagefind v4.0.12

Usage:
  pagefind [--input input.css] [--output output.css] [--watch] [options…]

Options:
  -i, --input ··········· Input file
  -o, --output ·········· Output file [default: `-`]
  -w, --watch ··········· Watch for changes and rebuild as needed
  -m, --minify ·········· Optimize and minify the output
      --optimize ········ Optimize the output without minifying
      --cwd ············· The current working directory [default: `.`]
  -h, --help ············ Display usage information
```


## Troubleshooting

### `ERROR: Cannot find the pagefind executable` for supported platform

Some users are reporting this error even when running on one of the supported native platforms:

- arm64-darwin
- x64-mingw32
- x64-mingw-ucrt
- x86_64-darwin
- x86_64-linux
- aarch64-linux

#### Check Bundler PLATFORMS

A possible cause of this is that Bundler has not been told to include native gems for your current platform. Please check your `Gemfile.lock` file to see whether your native platform is included in the `PLATFORMS` section. If necessary, run:

``` sh
bundle lock --add-platform <platform-name>
```

and re-bundle.


#### Check BUNDLE_FORCE_RUBY_PLATFORM

Another common cause of this is that bundler is configured to always use the "ruby" platform via the
`BUNDLE_FORCE_RUBY_PLATFORM` config parameter being set to `true`. Please remove this configuration:

``` sh
bundle config unset force_ruby_platform
# or
bundle config set --local force_ruby_platform false
```

and re-bundle.

See https://bundler.io/man/bundle-config.1.html for more information.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bangseongbeom/pagefind-ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/bangseongbeom/pagefind-ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Pagefind is [released under the MIT License](https://github.com/Pagefind/pagefind/blob/next/LICENSE).

## Code of Conduct

Everyone interacting in the Pagefind project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bangseongbeom/pagefind-ruby/blob/main/CODE_OF_CONDUCT.md).
