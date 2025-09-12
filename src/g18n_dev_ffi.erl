-module(g18n_dev_ffi).
-export([exit/1]).

%% Erlang FFI implementation for process control
%% 
%% Uses halt/1 which properly exits the process with the given status code
%% This ensures exit codes work correctly in CI/CD environments

exit(Code) ->
    halt(Code).