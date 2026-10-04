# Pagefind

[![ci](https://github.com/bangseongbeom/pagefind-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/bangseongbeom/pagefind-ruby/actions/workflows/ci.yml)
[![Ruby Code Style](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/standardrb/standard)
[![Gem Version](https://badge.fury.io/rb/pagefind.svg)](https://badge.fury.io/rb/pagefind)

A self-contained `pagefind` executable, with an indexing API, wrapped up in a ruby gem. That's it. Nothing else.

This gem is based on [tailwindcss-ruby](https://github.com/flavorjones/tailwindcss-ruby). Much of the packaging approach, code, and documentation was adapted from it. The indexing API was adapted from Pagefind's [Python](https://pagefind.app/docs/py-api/) and [NodeJS](https://pagefind.app/docs/node-api/) wrappers.


## Installation

This gem wraps [the precompiled binary](https://pagefind.app/docs/installation/#downloading-a-precompiled-binary) of Pagefind. These binaries are platform specific, so there are actually separate underlying gems per platform, but the correct gem will automatically be picked for your platform.

Supported platforms are:

- arm64-darwin (aarch64-apple-darwin)
- x86_64-darwin (x86_64-apple-darwin)
- x64-mingw-ucrt (x86_64-pc-windows-msvc)
- aarch64-mingw-ucrt (aarch64-pc-windows-msvc)
- x86_64-linux (x86_64-unknown-linux-musl)
- aarch64-linux (aarch64-unknown-linux-musl)
- amd64-freebsd (x86_64-unknown-freebsd)

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add pagefind
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install pagefind
```

### Using a local installation of `pagefind`

If you are not able to use the vendored precompiled binaries (for example, if you're on an unsupported platform), you can use a [local installation](https://pagefind.app/docs/installation/) of the `pagefind_extended` or `pagefind` binary by setting an environment variable named `PAGEFIND_INSTALL_DIR` to the directory path containing the binary.

For example, if you've [built Pagefind from source](https://pagefind.app/docs/installation/#building-from-source) with `cargo install pagefind` so that the binary is found at `$HOME/.cargo/bin/pagefind`, then you should set your environment variable like so:

``` sh
PAGEFIND_INSTALL_DIR=$HOME/.cargo/bin
```

or, if you've installed the [npm wrapper package](https://pagefind.app/docs/installation/#running-via-npx) so that the executable is found at a relative path like `./node_modules/.bin/pagefind`:

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
# => "/path/to/installs/ruby/3.3.5/lib/ruby/gems/3.3.0/gems/pagefind-1.5.2-x86_64-linux/exe/x86_64-linux/pagefind_extended"
```


### Command line

This gem provides an executable `pagefind` shim that will run the vendored standalone executable.

``` bash
# where is the shim?
$ bundle exec which pagefind
/path/to/installs/ruby/3.3/bin/pagefind

# run the actual executable through the shim
$ bundle exec pagefind --help
["/path/to/installs/installs/ruby/3.4.2/lib/ruby/gems/3.4.0/gems/pagefind-1.5.2-x86_64-linux/exe/x86_64-linux/pagefind_extended", "--help"]
Implement search on any static website.

Usage: pagefind_extended [OPTIONS]

Options:
  -s, --site <SITE>
          The location of your built static website
      --output-subdir <OUTPUT_SUBDIR>
          Where to output the search bundle, relative to the processed site
      --output-path <OUTPUT_PATH>
          Where to output the search bundle, relative to the working directory of the command
  ...
```


## Indexing API

This gem also provides an interface to the indexing binary as a Ruby library you can require.

There are situations where using this library is beneficial:

- Integrating Pagefind into an existing Ruby project, e.g. writing a plugin for a static site generator that can pass in-memory HTML files to Pagefind.
  Pagefind can also return the search index in-memory, to be hosted via the dev mode alongside the files.
- Users looking to index their site and augment that index with extra non-HTML pages can run a standard Pagefind crawl with [`add_directory`](#indexadd_directory) and augment it with [`add_custom_record`](#indexadd_custom_record).
- Users looking to use Pagefind's engine for searching miscellaneous content such as PDFs or subtitles, where [`add_custom_record`](#indexadd_custom_record) can be used to build the entire index from scratch.

### Example usage

<!-- this example is copied verbatim from test/integration.rb -->

``` ruby
require "pagefind"

html_content = <<~HTML
  <html>
    <body>
      <main>
        <h1>Example HTML</h1>
        <p>This is an example HTML page.</p>
      </main>
    </body>
  </html>
HTML

Pagefind::Index.open(root_selector: "main", logfile: "index.log", output_path: "./output", verbose: true) do |index|
  new_file = index.add_html_file(
    content: html_content,
    url: "https://example.com",
    source_path: "other/example.html"
  )
  new_record = index.add_custom_record(
    url: "/elephants/",
    content: "Some testing content regarding elephants",
    language: "en",
    meta: {title: "Elephants"}
  )
  new_dir = index.add_directory("./public")
  pp new_file, new_record, new_dir

  index.get_files.each do |file|
    puts "#{file[:content].bytesize.to_s.rjust(10)}B #{file[:path]}"
  end
end
```

All methods are synchronous: each one blocks until the native Pagefind binary running in the background responds. Pagefind handles one request at a time, so threads sharing an index or a service take turns.

Responses are returned as hashes with symbol keys.

### Pagefind::Index

`Pagefind::Index` manages a Pagefind index.

`Pagefind::Index.open` yields the index to a block and returns the block's value.
Entering the block starts a backing Pagefind service and creates an in-memory index in the backing service.
Exiting the block writes the in-memory index to disk and then shuts down the backing Pagefind service.

``` ruby
Pagefind::Index.open do |index| # open the index
  # update the index
end
# the index is closed here and files are written to disk.
```

Each method of `Pagefind::Index` that talks to the backing Pagefind service can raise `Pagefind::ServiceError`.
If an exception is raised inside `Pagefind::Index.open`'s block, the block exits without writing the index files to disk.

``` ruby
Pagefind::Index.open do |index| # open the index
  index.add_directory("./public")
  raise "not today"
end
# the index closes without writing anything to disk
```

`Pagefind::Index.open` optionally takes keyword arguments that can apply parts of the [Pagefind CLI config](https://pagefind.app/docs/config-options/). The options available at this level are:

``` ruby
Pagefind::Index.open(
  root_selector: "main",
  exclude_selectors: ["nav"],
  force_language: "en",
  include_characters: "._",
  verbose: true,
  logfile: "index.log",
  keep_index_url: true,
  write_playground: true,
  output_path: "./output"
) do |index|
  # ...
end
```

See the relevant documentation for these configuration options in the [Configuring the Pagefind CLI](https://pagefind.app/docs/config-options/) documentation.

### index.add_directory

Indexes a directory from disk using the standard Pagefind indexing behaviour.
This is equivalent to running the Pagefind binary with `--site <dir>`.

``` ruby
# Index all the HTML files in the public directory
indexed_dir = index.add_directory("./public")
page_count = indexed_dir[:page_count] # Integer
```

If the `path` provided is relative, it will be relative to the current working directory of your Ruby process. Both `String` and `Pathname` are accepted.

``` ruby
# Index files in a directory matching a given glob pattern.
indexed_dir = index.add_directory("./public", glob: "**/*.{html}")
```

Optionally, a custom `glob` can be supplied which controls which files Pagefind will consume within the directory. The default is shown, and the `glob` option can be omitted entirely.
See [Wax patterns documentation](https://github.com/olson-sean-k/wax#patterns) for more details.

### index.add_html_file

Adds a virtual HTML file to the Pagefind index. Useful for files that don't exist on disk, for example a static site generator that is serving files from memory.

``` ruby
html_content = <<~HTML
  <html lang="en"><body>
    <h1>A Full HTML Document</h1>
    <p> ... </p>
  </body></html>
HTML

# Index a file as if Pagefind was indexing from disk
new_file = index.add_html_file(
  content: html_content,
  source_path: "other/example.html"
)

# Index HTML content, giving it a specific URL
new_file = index.add_html_file(
  content: html_content,
  url: "https://example.com"
)
```

The `source_path` should represent the path of this HTML file if it were to exist on disk. Pagefind will use this path to generate the URL. It should be relative, or absolute to a path within the current working directory.

Instead of `source_path`, a `url` may be supplied to explicitly set the URL of this search result.

The `content` should be the full HTML source, including the outer `<html> </html>` tags. This will be run through Pagefind's standard HTML indexing process, and should contain any required Pagefind attributes to control behaviour.

If successful, a hash is returned containing metadata about the completed indexing.

### index.add_custom_record

Adds a direct record to the Pagefind index.
Useful for adding non-HTML content to the search results.

``` ruby
custom_record = index.add_custom_record(
  url: "/contact/",
  content: "My raw content to be indexed for search. " \
    "Will be lightly processed by Pagefind.",
  language: "en",
  meta: {
    title: "Contact",
    category: "Landing Page"
  },
  filters: {tags: ["landing", "company"]},
  sort: {weight: "20"}
)

page_word_count = custom_record[:page_word_count] # Integer
page_url = custom_record[:page_url] # String
page_meta = custom_record[:page_meta] # Hash[Symbol, String]
```

The `url`, `content`, and `language` keyword arguments are all required. `language` should be an [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes).

`meta` is optional, and is strictly a flat hash of keys to string values.
See the [Metadata documentation](https://pagefind.app/docs/metadata/) for semantics.

`filters` is optional, and is strictly a flat hash of keys to arrays of string values.
See the [Filters documentation](https://pagefind.app/docs/filtering/) for semantics.

`sort` is optional, and is strictly a flat hash of keys to string values.
See the [Sort documentation](https://pagefind.app/docs/sorts/) for semantics.
*When Pagefind is processing an index, number-like strings will be sorted numerically rather than alphabetically. As such, the value passed in should be `"20"` and not `20`*

If successful, a hash is returned containing metadata about the completed indexing.

### index.get_files

Gets raw data of all files in the Pagefind index.
Useful for integrating a Pagefind index into the development mode of a static site generator and hosting these files yourself.

This method returns every file at once, which can be a lot of data.

``` ruby
index.get_files.each do |file|
  path = file[:path] # String
  content = file[:content] # binary String
  # ...
end
```

### index.write_files

Calling `index.write_files` writes the index files to disk, as they would be written when running the standard Pagefind binary directly.

Exiting `Pagefind::Index.open`'s block automatically calls `index.write_files`, so calling this method is not necessary in normal operation.

Calling this method won't prevent files being written when the block exits, which may cause duplicate files to be written.
If calling this method manually, you probably want to also call `index.delete_index`.

``` ruby
Pagefind::Index.open(output_path: "./public/pagefind") do |index|
  # ... add content to index

  # write files to the configured output path for the index:
  index.write_files

  # write files to a different output path:
  index.write_files("./custom/pagefind")

  # prevent also writing files when exiting the block:
  index.delete_index
end
```

The output path should contain the path to the desired Pagefind bundle directory. If relative, it is relative to the current working directory of your Ruby process.

### index.delete_index

Deletes the data for the given index from its backing Pagefind service.
Doesn't affect any written files or data returned by `get_files`.

``` ruby
index.delete_index
```

Calling `index.get_files` or `index.write_files` doesn't consume the index, and further modifications can be made. In situations where many indexes are being created, the `delete_index` call helps clear out memory from a shared Pagefind binary service.

Reusing a `Pagefind::Index` object after calling `index.delete_index` will raise `Pagefind::ServiceError`.

Not calling this method is fine — these indexes will be cleaned up when `Pagefind::Index.open`'s block exits, its backing Pagefind service closes, or your Ruby process exits.

### Pagefind::Service

`Pagefind::Service` manages a Pagefind service running in a subprocess.

When `Pagefind::Service.open` is given a block, the backing service starts, is yielded to the block, and shuts down when the block exits. Without a block, it returns the running service, which you should shut down with `close`.

``` ruby
service = Pagefind::Service.open
# ...
service.close

Pagefind::Service.open do |service| # the service launches
  # ...
end
# the service closes
```

You should invoke `Pagefind::Service` directly when you want to use the same backing service for many indexes. `service.create_index` takes the same options as `Pagefind::Index.open`.

Indexes created this way are not written to disk automatically, so call `write_files` yourself:

``` ruby
Pagefind::Service.open do |service|
  default_index = service.create_index
  other_index = service.create_index(output_path: "./search/nonstandard")

  default_index.add_directory("./a")
  other_index.add_directory("./b")

  default_index.write_files
  other_index.write_files
end
```


## Troubleshooting

### `ERROR: Cannot find the pagefind executable` for supported platform

Some users are reporting this error even when running on one of the supported native platforms:

- arm64-darwin
- x86_64-darwin
- x64-mingw-ucrt
- aarch64-mingw-ucrt
- x86_64-linux
- aarch64-linux
- amd64-freebsd

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

Pagefind is [released under the MIT License](https://github.com/Pagefind/pagefind/blob/main/LICENSE).

## Code of Conduct

Everyone interacting in the Pagefind project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/bangseongbeom/pagefind-ruby/blob/main/CODE_OF_CONDUCT.md).
