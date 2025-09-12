/// Process control utilities for handling exits
/// 
/// This module provides cross-platform process control functionality
/// using FFI to ensure proper exit codes for CI/CD environments.

/// Exit the process with the given status code
/// - 0 indicates success
/// - Non-zero indicates failure
@external(erlang, "g18n_dev_ffi", "exit")
@external(javascript, "./process_ffi.mjs", "exit")
pub fn exit(code: Int) -> Nil