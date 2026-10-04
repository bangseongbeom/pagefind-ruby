# frozen_string_literal: true

require "json"
require "open3"

module Pagefind
  # Raised when the backing Pagefind service reports an error, or when communicating with it fails.
  class ServiceError < StandardError
    # The original message that Pagefind failed to parse, if any.
    attr_reader :original_message #: String?

    #: (?String? message, ?original_message: String?) -> void
    def initialize(message = nil, original_message: nil)
      super(message)
      @original_message = original_message
    end
  end

  # Manages a backing Pagefind service, running as a `pagefind --service` process.
  #
  # Pagefind handles one request at a time, so threads sharing a service take turns.
  class Service
    # Launches a backing Pagefind service. If a block is given, yields the service and shuts it down
    # when the block exits, returning the block's value.
    #
    #: () -> Service
    #: [T] () { (Service) -> T } -> T
    def self.open
      service = new
      return service unless block_given?

      begin
        yield service
      ensure
        service.close
      end
    end

    # Launches a backing Pagefind service. Call #close to shut it down.
    #
    #: () -> void
    def initialize
      @message_id = 0
      @mutex = Thread::Mutex.new
      @stdin, @stdout, @wait_thread = Open3.popen2(Pagefind.executable, "--service")
      @stdin.binmode
      @stdout.binmode
    end

    # Creates an in-memory index in this service. Takes the same options as Index.new.
    #
    #: (?root_selector: String?, ?exclude_selectors: Array[String]?, ?force_language: String?, ?verbose: bool?, ?logfile: String?, ?keep_index_url: bool?, ?write_playground: bool?, ?include_characters: String?, ?output_path: (String | Pathname)?) -> Index
    def create_index(**) = Index.new(self, **)

    # Sends a request to the backing Pagefind service and returns its response.
    #
    # @rbs payload: Hash[Symbol, untyped] -- The request payload to send, such as `{type: "GetFiles", index_id: 0}`.
    # @rbs return: Hash[Symbol, untyped]
    def send_message(payload)
      response = nil
      @mutex.synchronize do
        raise ServiceError, "Pagefind service is not running" if @stdin.closed?

        begin
          write_message(message_id: (@message_id += 1), payload:)
          response = read_message
        ensure
          # the response wasn't read, so shut down before the next request reads it by mistake
          @stdin.close unless response
        end
      end
      result = response[:payload]

      if response[:message_id].nil?
        raise ServiceError.new("Pagefind service error when parsing a message: #{result[:message]}", original_message: result[:original_message])
      elsif result[:type] == "Error"
        raise ServiceError.new(result[:message], original_message: result[:original_message])
      end

      result
    end

    # Waits for any request in progress to finish, then shuts down the backing Pagefind service.
    #
    #: () -> nil
    def close
      @mutex.synchronize do
        @stdin.close # pagefind exits when its stdin reaches EOF
        @wait_thread.join
        @stdout.close
      end
    end

    private

    #: (Hash[Symbol, untyped] request) -> void
    def write_message(request)
      @stdin.write([JSON.generate(request)].pack("m0"), ",")
    rescue IOError, SystemCallError => e
      raise ServiceError, "Failed to send a message to the Pagefind service: #{e.message}"
    end

    #: () -> Hash[Symbol, untyped]
    def read_message
      output = @stdout.gets(",", chomp: true)
      raise ServiceError, "Pagefind service exited" if output.nil?

      JSON.parse(output.unpack1("m0"), symbolize_names: true)
    end
  end
end
