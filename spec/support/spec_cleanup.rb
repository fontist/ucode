# frozen_string_literal: true

require "fileutils"

# Spec helper that safely cleans up temp directories.
#
# On Windows, `FileUtils.remove_entry` frequently fails with
# `Errno::ENOTEMPTY` or `Errno::EACCES` because the OS holds
# locks on files that were recently written (especially by
# mutool, fontisan, or the SQLite library). The locks are not
# released until the process exits, making mid-test cleanup
# impossible.
#
# This module provides a single `safe_remove` method that
# silently skips on Windows (CI runners are ephemeral anyway)
# and swallows cleanup errors on all platforms so test results
# aren't polluted by filesystem-level cleanup failures.
module SpecCleanup
  # Removes a path if it exists. On Windows, this is a no-op —
  # Windows cannot reliably delete temp files/dirs while the
  # process is still running.
  #
  # @param path [String, Pathname, nil]
  def safe_remove(path)
    return if Gem.win_platform?
    return unless path

    resolved = path.to_s
    FileUtils.remove_entry_secure(resolved) if File.exist?(resolved)
  rescue Errno::ENOTEMPTY, Errno::EACCES, Errno::ENOENT
    # Locked dir or already gone — leave it for the OS.
  end
end
