# frozen_string_literal: true

require "test_helper"

class TestPagefind < Minitest::Spec
  def mock_exe_directory(platform)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir(File.join(dir, platform))
      path = File.join(dir, platform, "pagefind_extended")
      FileUtils.touch(path)
      stub_gem_platform_match_gem(true) do
        yield(dir, path)
      end
    end
  end

  def stub_gem_platform_match_gem(value)
    assert_respond_to(Gem::Platform, :match_gem?)
    Gem::Platform.stub(:match_gem?, value) do
      yield
    end
  end

  def mock_local_pagefind_install
    Dir.mktmpdir do |dir|
      path = File.join(dir, "pagefind")
      FileUtils.touch(path)
      yield(dir, path)
    end
  end

  it ".platform is a string containing just the cpu and os (not the version)" do
    expected = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
    assert_equal(expected, Pagefind.platform)
  end

  it ".executable returns the absolute path to the binary" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      expected = File.expand_path(File.join(dir, "sparc-solaris2.8", "pagefind_extended"))
      assert_equal(expected, executable, "assert on setup")
      assert_equal(expected, Pagefind.executable(exe_path: dir))
    end
  end

  it ".executable raises UnsupportedPlatformException when we're not on a supported platform" do
    stub_gem_platform_match_gem(false) do # nothing is supported
      assert_raises(Pagefind::UnsupportedPlatformException) do
        Pagefind.executable
      end
    end
  end

  it ".executable raises ExecutableNotFoundException when we can't find the executable we expect" do
    Dir.mktmpdir do |dir| # empty directory
      assert_raises(Pagefind::ExecutableNotFoundException) do
        Pagefind.executable(exe_path: dir)
      end
    end
  end

  it ".executable returns the executable in PAGEFIND_INSTALL_DIR when no packaged binary exists" do
    mock_local_pagefind_install do |local_install_dir, expected|
      result = nil
      begin
        ENV["PAGEFIND_INSTALL_DIR"] = local_install_dir
        assert_output(nil, /using PAGEFIND_INSTALL_DIR/) do
          result = Pagefind.executable(exe_path: "/does/not/exist")
        end
      ensure
        ENV["PAGEFIND_INSTALL_DIR"] = nil
      end
      assert_equal(expected, result)
    end
  end

  it ".executable returns the executable in PAGEFIND_INSTALL_DIR when we're not on a supported platform" do
    stub_gem_platform_match_gem(false) do # nothing is supported
      mock_local_pagefind_install do |local_install_dir, expected|
        result = nil
        begin
          ENV["PAGEFIND_INSTALL_DIR"] = local_install_dir
          assert_output(nil, /using PAGEFIND_INSTALL_DIR/) do
            result = Pagefind.executable
          end
        ensure
          ENV["PAGEFIND_INSTALL_DIR"] = nil
        end
        assert_equal(expected, result)
      end
    end
  end

  it ".executable returns the executable in PAGEFIND_INSTALL_DIR even when a packaged binary exists" do
    mock_exe_directory("sparc-solaris2.8") do |dir, _executable|
      mock_local_pagefind_install do |local_install_dir, expected|
        result = nil
        begin
          ENV["PAGEFIND_INSTALL_DIR"] = local_install_dir
          assert_output(nil, /using PAGEFIND_INSTALL_DIR/) do
            result = Pagefind.executable(exe_path: dir)
          end
        ensure
          ENV["PAGEFIND_INSTALL_DIR"] = nil
        end
        assert_equal(expected, result)
      end
    end
  end

  it ".executable raises ExecutableNotFoundException is PAGEFIND_INSTALL_DIR is set to a nonexistent dir" do
    ENV["PAGEFIND_INSTALL_DIR"] = "/does/not/exist"
    assert_raises(Pagefind::DirectoryNotFoundException) do
      Pagefind.executable
    end
  ensure
    ENV["PAGEFIND_INSTALL_DIR"] = nil
  end
end
