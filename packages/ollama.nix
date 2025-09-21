# ollama wrapper that launches ollama from XDG friendly paths
{ lib, ollama, stdenv, writeShellScriptBin }:

let

	ollama-path = "$HOME/.local/state/ollama";

in writeShellScriptBin "ollama" (''#!/bin/sh
	if ! test -d "${ollama-path}" ; then
		mkdir -p "${ollama-path}"
'' + lib.optionalString stdenv.isDarwin ''
		tmutil addexclusion "${ollama-path}"
'' + ''
	fi

	OLLAMA_NOHISTORY=1 \
	OLLAMA_MODELS="${ollama-path}" \
	HOME="${ollama-path}" \
	exec ${lib.getExe ollama} "$@"
'')
