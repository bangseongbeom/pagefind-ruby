# frozen_string_literal: true

module Pagefind
  # Manages a Pagefind index.
  #
  # Index.open yields the index to a block.
  # Entering the block starts a backing Pagefind service and creates an in-memory index in the backing service.
  # Exiting the block writes the in-memory index to disk and then shuts down the backing Pagefind service.
  #
  # Each method of Index that talks to the backing Pagefind service can raise ServiceError.
  # If an exception is raised inside Index.open's block, the block exits without writing the index files to disk.
  #
  # Index optionally takes configuration options that can apply parts of the [Pagefind CLI config](https://pagefind.app/docs/config-options/). The options available at this level are listed in Index.new.
  #
  # See the relevant documentation for these configuration options in the
  # [Configuring the Pagefind CLI](https://pagefind.app/docs/config-options/) documentation.
  class Index
    # Yields a new index to the block and returns the block's value. Takes the same options as
    # Index.new.
    #
    # You should invoke Service directly when you want to use the same backing service for
    # many indexes. See Service#create_index.
    #
    #: [T] (?root_selector: String?, ?exclude_selectors: Array[String]?, ?force_language: String?, ?verbose: bool?, ?logfile: String?, ?keep_index_url: bool?, ?write_playground: bool?, ?include_characters: String?, ?output_path: (String | Pathname)?) { (Index) -> T } -> T
    def self.open(**config)
      raise ArgumentError, "#{name}.open requires a block" unless block_given?

      Service.open do |service|
        index = new(service, **config)
        result = yield index
        index.write_files unless index.instance_variable_get(:@deleted)
        result
      end
    end

    # Creates an in-memory index in the backing Pagefind service.
    #
    # @rbs service: Service -- The backing Pagefind service to create the index in.
    # @rbs root_selector: String? -- The root selector to use for the index.
    #   If not supplied, Pagefind will use the `<html>` tag.
    # @rbs exclude_selectors: Array[String]? -- Extra element selectors that Pagefind should ignore when indexing.
    # @rbs force_language: String? -- Ignores any detected languages and creates a single index for the entire site as the
    #   provided language. Expects an ISO 639-1 code, such as `en` or `pt`.
    # @rbs verbose: bool? -- Prints extra logging while indexing the site. Only affects the CLI, does not impact
    #   web-facing search.
    # @rbs logfile: String? -- A path to a file to log indexing output to in addition to stdout.
    #   The file will be created if it doesn't exist and overwritten on each run.
    # @rbs keep_index_url: bool? -- Whether to keep `index.html` at the end of search result paths.
    #   By default, a file at `animals/cat/index.html` will be given the URL
    #   `/animals/cat/`. Setting this option to `true` will result in the URL
    #   `/animals/cat/index.html`.
    # @rbs write_playground: bool? -- When writing or outputting files, also write the Pagefind playground to /pagefind/playground/.
    #   Defaults to false, ensuring the playground isn't available on a live site.
    # @rbs include_characters: String? -- Include these characters when indexing and searching words.
    #   Useful for sites documenting technical topics such as programming languages.
    # @rbs output_path: (String | Pathname)? -- The folder to output the search bundle into, relative to the working directory.
    #   Defaults to `pagefind`.
    # @rbs return: void
    def initialize(
      service,
      root_selector: nil,
      exclude_selectors: nil,
      force_language: nil,
      verbose: nil,
      logfile: nil,
      keep_index_url: nil,
      write_playground: nil,
      include_characters: nil,
      output_path: nil
    )
      @service = service
      @output_path = output_path

      config = {
        root_selector:,
        exclude_selectors:,
        force_language:,
        verbose:,
        logfile:,
        keep_index_url:,
        write_playground:,
        include_characters:
      }
      result = @service.send_message({type: "NewIndex", config:})
      @index_id = result[:index_id]
    end

    # Adds an HTML file to the index.
    #
    # @rbs content: String -- The source HTML content of the file to be parsed.
    # @rbs source_path: String? -- The source path the HTML file would have on disk.
    #   Must be a relative path, or an absolute path within the current working directory.
    #   Pagefind will compute the result URL from this path.
    # @rbs url: String? -- An explicit URL to use, instead of having Pagefind compute the
    #   URL based on the source_path. If not supplied, source_path must be supplied.
    # @rbs return: { type: "IndexedFile", page_word_count: Integer, page_url: String, page_meta: Hash[Symbol, String] }
    def add_html_file(content:, source_path: nil, url: nil)
      @service.send_message({type: "AddFile", index_id: @index_id, file_path: source_path, url:, file_contents: content})
    end

    # Adds a direct record to the Pagefind index.
    #
    # This method is useful for adding non-HTML content to the search results.
    #
    # @rbs content: String -- The raw content of this record.
    # @rbs url: String -- The output URL of this record. Pagefind will not alter this.
    # @rbs language: String -- ISO 639-1 code of the language this record is written in.
    # @rbs meta: Hash[String | Symbol, String]? -- The metadata to attach to this record. Supplying a `title` is highly recommended.
    # @rbs filters: Hash[String | Symbol, Array[String]]? -- The filters to attach to this record. Filters are used to group records together.
    # @rbs sort: Hash[String | Symbol, String]? -- The sort keys to attach to this record.
    # @rbs return: { type: "IndexedFile", page_word_count: Integer, page_url: String, page_meta: Hash[Symbol, String] }
    def add_custom_record(url:, content:, language:, meta: nil, filters: nil, sort: nil)
      @service.send_message({type: "AddRecord", index_id: @index_id, url:, content:, language:, meta:, filters:, sort:})
    end

    # Indexes a directory from disk using the standard Pagefind indexing behaviour.
    #
    # This is equivalent to running the Pagefind binary with `--site <dir>`.
    #
    # @rbs path: String | Pathname -- The path to the directory to index. If the `path` provided is relative,
    #   it will be relative to the current working directory of your Ruby process.
    # @rbs glob: String? -- A glob pattern to filter files in the directory. If not provided, all
    #   files matching `**/*.{html}` are indexed. For more information on glob patterns,
    #   see the [Wax patterns documentation](https://github.com/olson-sean-k/wax#patterns).
    # @rbs return: { type: "IndexedDir", page_count: Integer }
    def add_directory(path, glob: nil)
      @service.send_message({type: "AddDir", index_id: @index_id, path: path.to_s, glob:})
    end

    # Writes the index files to disk.
    #
    # If you're using Index.open, there's no need to call this method:
    # if no error occurred, exiting the block automatically writes the index files to disk.
    #
    # @rbs output_path: (String | Pathname)? -- A path to override the configured output path for the index.
    # @rbs return: { type: "WriteFiles", output_path: String }
    def write_files(output_path = @output_path)
      @service.send_message({type: "WriteFiles", index_id: @index_id, output_path: output_path&.to_s})
    end

    # Gets raw data of all files in the Pagefind index.
    #
    # This method emits all files, which can be a lot of data.
    #
    # @rbs return: Array[{ path: String, content: String }] -- Each file's `:content` is a binary string.
    def get_files
      result = @service.send_message({type: "GetFiles", index_id: @index_id})
      result[:files].map do |file|
        {path: file[:path], content: file[:content].unpack1("m0")}
      end
    end

    # Deletes the data for the given index from its backing Pagefind service.
    # Doesn't affect any written files or data returned by #get_files.
    #
    #: () -> void
    def delete_index
      @service.send_message({type: "DeleteIndex", index_id: @index_id})
      @deleted = true
    end
  end
end
