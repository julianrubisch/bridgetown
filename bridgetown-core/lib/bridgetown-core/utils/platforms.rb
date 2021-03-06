# frozen_string_literal: true

module Bridgetown
  module Utils
    module Platforms
      extend self

      # TODO: jruby is NOT supported by Bridgetown. This should probably
      # get removed.
      { jruby?: "jruby", mri?: "ruby" }.each do |k, v|
        define_method k do
          ::RUBY_ENGINE == v
        end
      end

      # --
      # Allows you to detect "real" Windows, or what we would consider
      # "real" Windows.  That is, that we can pass the basic test and the
      # /proc/version returns nothing to us.
      # --

      def vanilla_windows?
        RbConfig::CONFIG["host_os"] =~ %r!mswin|mingw|cygwin!i && \
          !proc_version
      end

      # --
      # XXX: Remove in 4.0
      # --

      alias_method :really_windows?, \
                   :vanilla_windows?

      #

      def bash_on_windows?
        RbConfig::CONFIG["host_os"] =~ %r!linux! && \
          proc_version =~ %r!microsoft!i
      end

      #

      def windows?
        vanilla_windows? || bash_on_windows?
      end

      #

      def linux?
        RbConfig::CONFIG["host_os"] =~ %r!linux! && \
          proc_version !~ %r!microsoft!i
      end

      # Provides windows?, linux?, osx?, unix? so that we can detect
      # platforms. This is mostly useful for `bridgetown doctor` and for testing
      # where we kick off certain tests based on the platform.

      { osx?: %r!darwin|mac os!, unix?: %r!solaris|bsd! }.each do |k, v|
        define_method k do
          !!(
            RbConfig::CONFIG["host_os"] =~ v
          )
        end
      end

      #

      private

      def proc_version
        @proc_version ||=
          begin
            File.read("/proc/version")
          rescue Errno::ENOENT, Errno::EACCES
            nil
          end
      end
    end
  end
end
