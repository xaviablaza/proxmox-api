# proxmox-api

## What is it?
ProxmoxAPI is a Ruby gem that provides a fluent, object-oriented wrapper for the [Proxmox VE REST API](https://pve.proxmox.com/pve-docs/api-viewer/index.html). It allows Ruby applications to interact with Proxmox Virtual Environment servers through an intuitive method-chaining interface, abstracting away the complexity of direct HTTP API calls.

### Key Features
- **Fluent Interface**: Build API paths using natural Ruby method chaining (e.g., `client.nodes.pve1.lxc[101].status.current.get`)
- **Flexible Authentication**: Supports both username/password and API token authentication
- **Modern HTTP Client**: Built on Faraday with SSL/TLS configuration support
- **Dynamic Path Building**: Automatically constructs REST endpoints from method chains and bracket notation
- **Error Handling**: Custom exceptions with detailed server response information
- **Safe Operations**: Optional "dangerous" methods to ignore HTTP error codes when needed

## Usage

### Installation
You can add this gem to your Gemfile and use bundler:
```ruby
gem 'proxmox-api', git: 'https://github.com/xaviablaza/proxmox-api'
```

### Authentication

The gem supports two authentication methods for connecting to Proxmox VE servers:

#### 1. Username/Password Authentication
Uses traditional credentials to obtain an authentication ticket:
```ruby
require 'proxmox_api'

client = ProxmoxAPI.new(
  'proxmox-host.example.org',
  username: 'root', 
  password: 'password', 
  realm: 'pam', 
  verify_ssl: false
)
```

Available options:
- `:username` - Proxmox username
- `:password` - User password  
- `:realm` - Authentication realm (e.g., 'pam', 'pve')
- `:otp` - One-time password for two-factor authentication

#### 2. API Token Authentication (Recommended)
Uses API tokens for secure, programmatic access:
```ruby
require 'proxmox_api'

client = ProxmoxAPI.new(
  'proxmox-host.example.org',
  token: 'root@pam!tokenid', 
  secret: 'cdbb8fce-c068-4a9b-ade1-a00043db818a', 
  verify_ssl: false
)
```

#### SSL/TLS Configuration
The gem supports comprehensive SSL configuration through Faraday:
- `:verify_ssl` - Enable/disable SSL certificate verification
- `:ca_file` - Path to custom CA certificate file
- `:ca_path` - Path to directory containing CA certificates
- `:port` - Custom port (defaults to 8006)

The constructor will automatically authenticate and raise `ProxmoxAPI::ApiException` if authentication fails.    

### Making API Requests

The gem provides an intuitive fluent interface for building and executing Proxmox API requests. Chain method calls to build the API path, then call an HTTP method to execute the request.

#### Basic Usage Pattern
```ruby
client.path.to.resource.get     # GET request
client.path.to.resource.post(data)   # POST with data
client.path.to.resource.put(data)    # PUT with data  
client.path.to.resource.delete       # DELETE request
```

#### Flexible Path Building
The gem supports multiple ways to build API paths:
```ruby
# Get current status of LXC container 101 on node 'pve1'
client.nodes['pve1'].lxc[101].status.current.get
client.nodes.pve1.lxc[101].status.current.get         # Method chaining
client.nodes.pve1.lxc[101].status[:current].get       # Mixed notation
client['nodes/pve1/lxc/101/status/current'].get       # Full path string
```

#### Common Operations
```ruby
# List all nodes
client.nodes.get

# Get node status
client.nodes['pve1'].status.get

# List containers on a node
client.nodes.pve1.lxc.get

# Create a user
client.access.users.post(userid: 'user@pve', password: 'password')

# Assign permissions
client.access.acl.put(path: 'vms/101', users: 'user@pve', roles: 'PVEAdmin')

# Start a VM
client.nodes.pve1.qemu[101].status.start.post

# Create a backup
client.nodes.pve1.vzdump.post(vmid: 101, storage: 'local', compress: 'gzip')
```

#### Error Handling
By default, HTTP error status codes raise `ProxmoxAPI::ApiException` with the server response:
```ruby
begin
  client.invalid.path.get
rescue ProxmoxAPI::ApiException => e
  puts "API Error: #{e.message}"
  puts "Status: #{e.response.status}"
  puts "Response: #{e.response.body}"
end
```

#### "Dangerous" Methods
Add `!` to any HTTP method to ignore error status codes and return `nil` for failed requests:
```ruby
# Check if user exists without raising exceptions
user_data = client.access.users['user@pve'].get!
user_exists = !user_data.nil?
```

## Architecture

### Core Components

- **ProxmoxAPI**: Main class handling authentication and HTTP connections via Faraday
- **ApiPath**: Nested class that builds API paths dynamically using method chaining and bracket notation  
- **ApiException**: Custom exception class that wraps Faraday responses for detailed error information

### Design Patterns

- **Fluent Interface**: Natural Ruby method chaining for building API endpoints
- **Dynamic Method Dispatch**: Uses `method_missing` to handle arbitrary API paths at runtime
- **Modern HTTP Client**: Built on Faraday with configurable SSL/TLS support and JSON request/response handling

## Development

### Requirements
- Ruby 3.0 or higher
- Bundler for dependency management

### Setup
```bash
bundle install
```

### Testing
```bash
bundle exec rspec              # Run all tests
bundle exec rspec spec/api_path_spec.rb  # Run specific test file
```

### Code Quality
```bash
bundle exec rubocop           # Check code style
bundle exec rubocop -a        # Auto-fix violations
bundle exec rake              # Run both RuboCop and RSpec
```

### Building
```bash
gem build proxmox-api.gemspec
```

## Contributing

Feel free to create an [issue](https://github.com/xaviablaza/proxmox-api/issues)
or [pull request](https://github.com/xaviablaza/proxmox-api/pulls) on [GitHub](https://github.com/xaviablaza/proxmox-api).

## License

This project is licensed under the MIT License - see the LICENSE file for details.
