# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem that provides a wrapper for the Proxmox VE REST API. The gem allows Ruby applications to interact with Proxmox Virtual Environment servers through a fluent API interface using method chaining.

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/api_path_spec.rb` - Run specific test file

### Code Quality
- `bundle exec rubocop` - Run RuboCop linter
- `bundle exec rubocop -a` - Auto-correct RuboCop offenses
- `bundle exec rake` - Run default task (both RuboCop and RSpec)

### Build and Release
- `gem build proxmox-api.gemspec` - Build the gem
- `bundle install` - Install dependencies

## Architecture

### Core Components

- **ProxmoxAPI** (`lib/proxmox_api.rb`) - Main class that handles authentication and connection setup using Faraday
- **ApiPath** (nested in `ProxmoxAPI`) - Builds API paths dynamically using method chaining and bracket notation
- **ApiException** (nested in `ProxmoxAPI`) - Custom exception for API errors with Faraday response

### Key Design Patterns

- **Fluent Interface**: The API uses method chaining to build REST endpoints (e.g., `client.nodes.pve1.lxc[101].status.current.get`)
- **Dynamic Method Dispatch**: Both `ProxmoxAPI` and `ApiPath` use `method_missing` to handle arbitrary API paths
- **Authentication Flexibility**: Supports both username/password and API token authentication

### HTTP Client Migration

The gem has been migrated from RestClient to Faraday:
- Connection setup uses Faraday with url_encoded requests
- SSL verification handled through Faraday's SSL configuration
- Request/response handling abstracted through helper methods for better maintainability

### Authentication Methods

1. **Ticket-based**: Uses username, password, realm, and optional OTP via `/access/ticket` endpoint
2. **Token-based**: Uses API token and secret in Authorization header (preferred for automation)

### HTTP Method Mapping

- Standard methods: `get`, `post`, `put`, `delete`
- Dangerous methods: `get!`, `post!`, `put!`, `delete!` (ignore error status codes)

## Development Notes

- Target Ruby version: 3.0+
- Dependencies managed in Gemfile (not gemspec): `faraday` for HTTP requests, `json` for parsing
- All code uses `frozen_string_literal: true`
- RuboCop configuration: targets Ruby 3.0, max method length 20 lines, enables new cops
- Tests use RSpec with doubles for mocking HTTP requests
- Code follows method extraction pattern to keep complexity low (AbcSize < 17)