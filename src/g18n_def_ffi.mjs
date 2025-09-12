/// JavaScript FFI implementation for process control

export function exit(code) {
  if (typeof process !== 'undefined' && process.exit) {
    // Node.js environment
    process.exit(code);
  } else if (typeof Deno !== 'undefined' && Deno.exit) {
    // Deno environment
    Deno.exit(code);
  } else {
    // Browser or other environment - throw error as fallback
    throw new Error(`Process exit with code: ${code}`);
  }
}