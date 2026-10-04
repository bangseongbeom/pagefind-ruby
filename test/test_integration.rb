# frozen_string_literal: true

require "test_helper"

# The README's example is copied verbatim from test/integration.rb.
class TestIntegration < Minitest::Spec
  def setup
    @original_dir = Dir.pwd
    @dir = Dir.mktmpdir
    Dir.chdir(@dir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@dir)
  end

  it "runs the README's example" do
    capture_io do
      load File.expand_path("integration.rb", __dir__)
    end
  end

  it "matches the README's example" do
    readme = File.read(File.expand_path("../README.md", __dir__))
    example = File.read(File.expand_path("integration.rb", __dir__))

    assert(readme.include?("``` ruby\n#{example}```\n"))
  end
end
