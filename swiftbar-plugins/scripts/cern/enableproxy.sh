#!/bin/bash

PROXY_PORT=$1

# Enable SOCKS proxy
networksetup -setsocksfirewallproxy "Wi-Fi" "127.0.0.1" "$PROXY_PORT"
networksetup -setsocksfirewallproxystate "Wi-Fi" on

# Disable proxy on interruption
trap 'networksetup -setsocksfirewallproxystate "Wi-Fi" off; exit' INT TERM
