# frozen_string_literal: true
require "spec_helper"

describe "bundle install" do
  describe "with --path" do
    before :each do
      build_gem "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "puts 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "does not use available system gems with bundle --path vendor/bundle" do
      bundle "install --path vendor/bundle"
      should_be_installed "rack 1.0.0"
    end

    it "handles paths with regex characters in them" do
      dir = bundled_app("bun++dle")
      dir.mkpath

      Dir.chdir(dir) do
        bundle "install --path vendor/bundle"
        expect(out).to include("installed into ./vendor/bundle")
      end

      dir.rmtree
    end

    it "prints a warning to let the user know what has happened with bundle --path vendor/bundle" do
      bundle "install --path vendor/bundle"
      expect(out).to include("gems are installed into ./vendor")
    end

    it "disallows --path vendor/bundle --system" do
      bundle "install --path vendor/bundle --system"
      expect(out).to include("Please choose.")
    end

    it "remembers to disable system gems after the first time with bundle --path vendor/bundle" do
      bundle "install --path vendor/bundle"
      FileUtils.rm_rf bundled_app("vendor")
      bundle "install"

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end
  end

  describe "when BUNDLE_PATH or the global path config is set" do
    before :each do
      build_lib "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    def set_bundle_path(type, location)
      if type == :env
        ENV["BUNDLE_PATH"] = location
      elsif type == :global
        bundle "config path #{location}", "no-color" => nil
      end
    end

    [:env, :global].each do |type|
      it "installs gems to a path if one is specified" do
        set_bundle_path(type, bundled_app("vendor2").to_s)
        bundle "install --path vendor/bundle"

        expect(vendored_gems("gems/rack-1.0.0")).to be_directory
        expect(bundled_app("vendor2")).not_to be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH with #{type}" do
        set_bundle_path(type, bundled_app("vendor").to_s)

        bundle :install

        expect(bundled_app("vendor/gems/rack-1.0.0")).to be_directory
        should_be_installed "rack 1.0.0"
      end

      it "installs gems to BUNDLE_PATH relative to root when relative" do
        set_bundle_path(type, "vendor")

        FileUtils.mkdir_p bundled_app("lol")
        Dir.chdir(bundled_app("lol")) do
          bundle :install
        end

        expect(bundled_app("vendor/gems/rack-1.0.0")).to be_directory
        should_be_installed "rack 1.0.0"
      end
    end

    it "installs gems to BUNDLE_PATH from .bundle/config" do
      config "BUNDLE_PATH" => bundled_app("vendor/bundle").to_s

      bundle :install

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end

    it "sets BUNDLE_PATH as the first argument to bundle install" do
      bundle "install --path ./vendor/bundle"

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end

    it "disables system gems when passing a path to install" do
      # This is so that vendored gems can be distributed to others
      build_gem "rack", "1.1.0", :to_system => true
      bundle "install --path ./vendor/bundle"

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      should_be_installed "rack 1.0.0"
    end
  end

  describe "to a dead symlink" do
    before do
      in_app_root do
        `ln -s /tmp/idontexist bundle`
      end
    end

    it "reports the symlink is dead" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      bundle "install --path bundle"
      expect(out).to match(/invalid symlink/)
    end
  end
end
