# frozen_string_literal: true

require "test_helper"
require "zlib"

class TestPagefindIndex < Minitest::Spec
  def setup
    @original_dir = Dir.pwd
    @dir = Dir.mktmpdir
    Dir.chdir(@dir)

    FileUtils.mkdir_p("public")
    File.write("public/index.html", %(<!DOCTYPE html><html lang="en"><head></head><body> <p data-url>Nothing</p></body></html>))
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@dir)
  end

  def indexed_pages(bundle_dir)
    Dir[File.join(bundle_dir, "fragment", "*")].map do |path|
      JSON.parse(Zlib.gunzip(File.binread(path)).delete_prefix("pagefind_dcd"))
    end
  end

  def indexed_urls(bundle_dir)
    indexed_pages(bundle_dir).map { |page| page["url"] }.sort
  end

  it "builds a synthetic index to disk via the API" do
    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "dogs/index.html")
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    assert_equal(["/dogs/"], indexed_urls("public/pagefind"))
  end

  it "builds a synthetic index with overridden URLs to disk via the API" do
    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/my-custom-url/")
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    assert_equal(["/my-custom-url/"], indexed_urls("public/pagefind"))
  end

  it "builds an index to a custom disk location via the API" do
    FileUtils.mkdir_p("output")
    File.write("output/index.html", %(<!DOCTYPE html><html lang="en"><head></head><body> <p data-url>Nothing</p></body></html>))

    Dir.chdir("public") do
      Pagefind::Index.open(output_path: "../output/pagefind") do |index|
        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "dogs/index.html")
      end
    end

    assert(File.size?("output/pagefind/pagefind.js"))
    assert_equal(["/dogs/"], indexed_urls("output/pagefind"))
  end

  it "builds a true index to disk via the API" do
    FileUtils.mkdir_p("public/custom_files/real")
    File.write("public/custom_files/real/index.html", %(<!DOCTYPE html><html lang="en"><head></head><body> <p>A testing file that exists on disk</p></body></html>))

    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        index.add_directory("custom_files")
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    assert_equal(["/real/"], indexed_urls("public/pagefind"))
  end

  it "builds a synthetic index to memory via the API" do
    Pagefind::Index.open do |index|
      index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "dogs/index.html")

      files = index.get_files

      js = files.find { |file| file[:path].include?("pagefind.js") }
      assert_includes(js[:content], "pagefind_version=")
      assert_equal("pagefind.js", js[:path])
      assert_equal(Encoding::BINARY, js[:content].encoding)

      fragments = files.select { |file| file[:path].include?("fragment") }
      assert_equal(1, fragments.length)
    end

    refute_path_exists("public/pagefind/pagefind.js")
  end

  it "builds a blended index to memory via the API" do
    FileUtils.mkdir_p("public/custom_files/real")
    File.write("public/custom_files/real/index.html", %(<!DOCTYPE html><html lang="en"><head></head><body> <p>A testing file that exists on disk</p></body></html>))

    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        index.add_directory("custom_files")
        index.add_custom_record(
          url: "/synth/",
          content: "A testing file that doesn't exist.",
          language: "en"
        )

        files = index.get_files

        files.each do |file|
          output_path = File.join("pagefind", file[:path])
          FileUtils.mkdir_p(File.dirname(output_path))
          File.binwrite(output_path, file[:content])
        end
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    assert_equal(["/real/", "/synth/"], indexed_urls("public/pagefind"))
  end

  it "returns assets for an empty index" do
    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        paths = index.get_files.map { |file| file[:path] }

        %w[pagefind.js pagefind-ui.js pagefind-ui.css pagefind-modular-ui.js pagefind-modular-ui.css wasm.unknown.pagefind].each do |path|
          assert_includes(paths, path)
        end

        index.delete_index
      end
    end
  end

  it "doesn't consume an index on write" do
    FileUtils.mkdir_p("output")
    File.write("output/index.html", %(<!DOCTYPE html><html lang="en"><head></head><body> <p data-url>Nothing</p></body></html>))

    Dir.chdir("public") do
      Pagefind::Index.open(output_path: "./pagefind") do |index|
        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "dogs/index.html")
        index.write_files("../output/pagefind")

        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "rabbits/index.html")

        files = index.get_files

        fragments = files.select { |file| file[:path].include?("fragment") }
        assert_equal(2, fragments.length)

        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", source_path: "cats/index.html")
      end
    end

    assert(File.size?("output/pagefind/pagefind.js"))
    assert_equal(["/dogs/"], indexed_urls("output/pagefind"))
    assert_equal(["/cats/", "/dogs/", "/rabbits/"], indexed_urls("public/pagefind"))
  end

  it "doesn't write the files when the block raises" do
    assert_raises(RuntimeError) do
      Pagefind::Index.open(output_path: "search") do |index|
        index.add_html_file(content: "<html><body><h1>Testing, testing</h1></body></html>", url: "/")
        raise "boom"
      end
    end
    refute_path_exists("search")
  end

  it "applies the service config" do
    Dir.chdir("public") do
      Pagefind::Index.open(root_selector: "h1", exclude_selectors: ["span"], keep_index_url: true) do |index|
        index.add_html_file(content: "<h1>Testing, <span>testing</span></h1>", source_path: "dogs/index.html")
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    page = indexed_pages("public/pagefind").first
    assert_equal("/dogs/index.html", page["url"])
    assert_equal("Testing,", page["content"])
  end

  it "lets force language take precedence over records" do
    Dir.chdir("public") do
      Pagefind::Index.open(force_language: "fr") do |index|
        index.add_custom_record(url: "/one/", content: "Testing file #1", language: "pt")
        index.add_html_file(source_path: "two/index.html", content: "<html lang='en'><body><h1>Testing file #2</h1></body></html>")
      end
    end

    assert(File.size?("public/pagefind/pagefind.js"))
    assert_path_exists("public/pagefind/wasm.unknown.pagefind")
    assert_path_exists("public/pagefind/wasm.fr.pagefind")
    refute_path_exists("public/pagefind/wasm.pt.pagefind")
    refute_path_exists("public/pagefind/wasm.en.pagefind")
  end

  it "builds the Pagefind playground via the API" do
    Dir.chdir("public") do
      Pagefind::Index.open(write_playground: true) do |index|
        index.add_custom_record(url: "/one/", content: "Testing file #1", language: "en")
        index.add_html_file(source_path: "two/index.html", content: "<html lang='en'><body><h1>Testing file #2</h1></body></html>")
      end
    end

    assert_includes(File.read("public/pagefind/playground/index.html"), %(<script src="./pagefind-playground.js">))

    js = File.read("public/pagefind/playground/pagefind-playground.js")
    assert_match(%r{<h1[^>]*>Pagefind Playground</h1>}, js)
    assert_match(%r{<details[^>]*><summary[^>]*>Details</summary>}, js)
  end

  it "closes the Pagefind backend" do
    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        paths = index.get_files.map { |file| file[:path] }
        assert_includes(paths, "pagefind.js")
        assert_includes(paths, "pagefind-ui.js")

        index.delete_index

        assert_raises(Pagefind::ServiceError) do
          index.get_files
        end
      end
    end
  end

  it "handles Pagefind errors" do
    Dir.chdir("public") do
      Pagefind::Index.open do |index|
        index.delete_index
        assert_raises(Pagefind::ServiceError) do
          index.get_files
        end
      end

      error = assert_raises(Pagefind::ServiceError) do
        Pagefind::Index.open(root_selector: 5) do |index|
          index.delete_index
        end
      end
      assert_match(/invalid type: integer `5`/, error.message)
    end
  end
end
