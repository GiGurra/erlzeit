#!/bin/bash

set -e

# Compile
echo "Compiling"
rebar3 compile

# Run erlfmt
echo "Running erlfmt on all files"
rebar3 fmt -w "{src,test,config,include}/*.{hrl,erl,app.src}"
rebar3 fmt -w rebar.config

# Run dialyzer
echo "Running dialyzer"
rebar3 dialyzer

# Run tests
echo "Running tests"
rebar3 eunit
