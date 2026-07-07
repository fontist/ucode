# frozen_string_literal: true

require "fileutils"

# Spec helpers for filesystem cleanup in tests.
#
# Two distinct use cases live here:
#
#   * `safe_remove` — best-effort cleanup of test fixtures in `after`
#     blocks. On Windows, OS locks on files recently written by
#     mutool/fontisan/SQLite make mid-process deletion unreliable, so
#     this method is a no-op on Windows and swallows lock errors
#     elsewhere. Use this when leftover files don't affect test
#     correctness.
#
#   * `force_remove_dir` — unconditional removal of a freshly-created
#     empty directory. Use this in `around` setup when about to
#     `cp_r` a fixture directory into a path that was pre-created by
#     `Cache.ensure_version_dir!`. Without this, `cp_r(src, existing_dst)`
#     nests the copy at `dst/src/` rather than replacing `dst`, which
#     breaks the spec setup on Windows (where `safe_remove` is a
#     no-op).
module SpecCleanup
  # @param path [String, Pathname, nil]
  def safe_remove(path)
    return if Gem.win_platform?
    return unless path

    resolved = path.to_s
    FileUtils.remove_entry_secure(resolved) if File.exist?(resolved)
  rescue Errno::ENOTEMPTY, Errno::EACCES, Errno::ENOENT
    # Locked dir or already gone — leave it for the OS.
  end

  # Removes a directory and all contents. Unlike {safe_remove}, this
  # is NOT a no-op on Windows — callers must guarantee the dir is
  # safe to remove (e.g., freshly created, no held locks).
  #
  # @param path [String, Pathname, nil]
  def force_remove_dir(path)
    return unless path

    resolved = path.to_s
    FileUtils.remove_entry_secure(resolved) if File.exist?(resolved)
  rescue Errno::ENOTEMPTY, Errno::EACCES
    # If the dir unexpectedly has held locks, fall back to rm_rf to
    # clear what we can. Tests downstream will fail loudly if a
    # needed file is missing.
    FileUtils.rm_rf(resolved, secure: true)
  end
end
