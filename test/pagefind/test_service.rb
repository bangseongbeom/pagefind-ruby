# frozen_string_literal: true

require "test_helper"
require "zlib"

class TestPagefindService < Minitest::Spec
  def setup
    @original_dir = Dir.pwd
    @dir = Dir.mktmpdir
    Dir.chdir(@dir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@dir)
  end

  def indexed_urls(files)
    files.select { |file| file[:path].start_with?("fragment/") }.map do |file|
      JSON.parse(Zlib.gunzip(file[:content]).delete_prefix("pagefind_dcd"))["url"]
    end.sort
  end

  it "yields the service to a block and closes it when the block returns" do
    yielded_service = nil
    result = Pagefind::Service.open do |service|
      yielded_service = service
      :done
    end

    assert_equal(:done, result)
    error = assert_raises(Pagefind::ServiceError) do
      yielded_service.send_message({type: "NewIndex", config: {}})
    end
    assert_match(/not running/, error.message)
  end

  it "closes the service when the block raises" do
    yielded_service = nil
    assert_raises(RuntimeError) do
      Pagefind::Service.open do |service|
        yielded_service = service
        raise "boom"
      end
    end

    assert_raises(Pagefind::ServiceError) do
      yielded_service.send_message({type: "NewIndex", config: {}})
    end
  end

  it "can be used without a block" do
    service = Pagefind::Service.open
    begin
      index = service.create_index(output_path: "search")
      index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/")
      index.write_files
    ensure
      service.close
    end
    assert_raises(Pagefind::ServiceError) do
      index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/")
    end
    assert_path_exists("search/pagefind-entry.json")
  end

  it "shares a service between indexes" do
    Pagefind::Service.open do |service|
      first = service.create_index
      second = service.create_index

      first.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/first/")
      second.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/second/")

      assert_equal(["/first/"], indexed_urls(first.get_files))
      assert_equal(["/second/"], indexed_urls(second.get_files))
    end
  end

  it "takes requests from multiple threads in turn" do
    Pagefind::Service.open do |service|
      index_id = service.send_message({type: "NewIndex", config: {}})[:index_id]

      results = 20.times.map do |i|
        Thread.new { service.send_message({type: "AddRecord", index_id:, url: "/#{i}/", content: "record #{i}", language: "en"}) }
      end.map(&:value)
      assert_equal(20.times.map { |i| "/#{i}/" }, results.map { |result| result[:page_url] })
    end
  end

  it "raises Pagefind::ServiceError when pagefind reports an error, and stays usable" do
    Pagefind::Service.open do |service|
      index_id = service.send_message({type: "NewIndex", config: {}})[:index_id]

      error = assert_raises(Pagefind::ServiceError) do
        service.send_message({type: "AddFile", index_id:, file_contents: "<html><body><h1>Testing, testing</h1></body></html>"})
      end
      assert_match(/source_path or url/, error.message)

      result = service.send_message({type: "AddFile", index_id:, url: "/", file_contents: "<html><body><h1>Testing, testing</h1></body></html>"})
      assert_equal("/", result[:page_url])
    end
  end

  it "raises Pagefind::ServiceError when pagefind can't parse a request" do
    Pagefind::Service.open do |service|
      error = assert_raises(Pagefind::ServiceError) do
        service.send_message({type: "NoSuchRequest"})
      end
      assert_match(/NoSuchRequest/, error.original_message)
    end
  end

  it "raises Pagefind::ServiceError when the service exits, and doesn't relaunch it" do
    skip "requires a POSIX shell" if Gem.win_platform?

    script = File.join(Dir.pwd, "exit-immediately")
    File.write(script, "#!/bin/sh\nexit 1\n")
    File.chmod(0o755, script)

    Pagefind.stub(:executable, script) do
      Pagefind::Service.open do |service|
        assert_raises(Pagefind::ServiceError) do
          service.send_message({type: "NewIndex", config: {}})
        end

        error = assert_raises(Pagefind::ServiceError) do
          service.send_message({type: "NewIndex", config: {}})
        end
        assert_match(/not running/, error.message)
      end
    end
  end
end
