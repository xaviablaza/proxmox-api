# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem that provides a wrapper for the Proxmox VE REST API. The gem allows Ruby applications to interact with Proxmox Virtual Environment servers through a fluent API interface.

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/api_path_spec.rb` - Run specific test file

### Code Quality
- `bundle exec rubocop` - Run RuboCop linter
- `bundle exec rake` - Run default task (both RuboCop and RSpec)

### Build and Release
- `gem build proxmox-api.gemspec` - Build the gem
- `bundle install` - Install dependencies

## Architecture

### Core Components

- **ProxmoxAPI** (`lib/proxmox_api.rb:10`) - Main class that handles authentication and connection setup
- **ApiPath** (`lib/proxmox_api.rb:16`) - Nested class that builds API paths dynamically using method chaining and bracket notation
- **ApiException** (`lib/proxmox_api.rb:50`) - Custom exception for API errors

### Key Design Patterns

- **Fluent Interface**: The API uses method chaining to build REST endpoints (e.g., `client.nodes.pve1.lxc[101].status.current.get`)
- **Dynamic Method Dispatch**: Both `ProxmoxAPI` and `ApiPath` use `method_missing` to handle arbitrary API paths
- **Authentication Flexibility**: Supports both username/password and API token authentication

### Authentication Methods

1. **Ticket-based**: Uses username, password, realm, and optional OTP
2. **Token-based**: Uses API token and secret (preferred for automation)

### HTTP Method Mapping

- Standard methods: `get`, `post`, `put`, `delete`
- Dangerous methods: `get!`, `post!`, `put!`, `delete!` (ignore error status codes)

## Development Notes

- Target Ruby version: 2.5+
- Dependencies: `rest-client` for HTTP requests, `json` for parsing
- All code uses `frozen_string_literal: true`
- RuboCop configuration enables new cops and targets Ruby 2.5
- Tests use RSpec with doubles for mocking