# frozen_string_literal: true

require 'rspec'
require_relative '../lib/proxmox_api'

describe 'ProxmoxAPI' do
  let(:api) do
    # Mock the HTTP connection setup to avoid network calls
    connection = double('Faraday::Connection')
    response_body = '{"data":{"ticket":"test","CSRFPreventionToken":"test"}}'
    allow(connection).to receive(:post).and_return(double('Response', status: 200, body: response_body))

    instance = ProxmoxAPI.allocate
    instance.instance_variable_set(:@connection, connection)
    instance.instance_variable_set(:@base_url, 'https://test.example.com:8006/api2/json/')
    instance.instance_variable_set(:@auth_ticket, {})
    instance
  end

  describe '#extract_error_message' do
    context 'with valid JSON error response' do
      it 'extracts message from Proxmox error response' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 400 }
        allow(response).to receive(:body) { '{"message": "VM is locked (backup)"}' }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('HTTP 400 - VM is locked (backup)')
      end

      it 'extracts message and field errors from Proxmox response' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 422 }
        allow(response).to receive(:body) do
          '{"message": "Parameter verification failed", "errors": {"vmid": "invalid format", "memory": "too large"}}'
        end

        error_message = api.send(:extract_error_message, response, 'Default message')
        expected_message = 'HTTP 422 - Parameter verification failed - (vmid: invalid format, memory: too large)'
        expect(error_message).to eq(expected_message)
      end

      it 'handles response with only field errors' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 400 }
        allow(response).to receive(:body) { '{"errors": {"node": "required field missing"}}' }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('HTTP 400 - (node: required field missing)')
      end

      it 'handles empty message field' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 500 }
        allow(response).to receive(:body) { '{"message": ""}' }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('Default message (HTTP 500)')
      end
    end

    context 'with invalid or empty response' do
      it 'handles malformed JSON response' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 500 }
        allow(response).to receive(:body) { 'invalid json' }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('Default message (HTTP 500)')
      end

      it 'handles empty response body' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 404 }
        allow(response).to receive(:body) { '' }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('Default message')
      end

      it 'handles nil response body' do
        response = double('Faraday::Response')
        allow(response).to receive(:status) { 502 }
        allow(response).to receive(:body) { nil }

        error_message = api.send(:extract_error_message, response, 'Default message')
        expect(error_message).to eq('Default message')
      end
    end
  end

  describe '#raise_on_failure' do
    it 'does not raise for successful responses' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 200 }

      expect { api.send(:raise_on_failure, response) }.not_to raise_error
    end

    it 'raises ApiException with extracted Proxmox error message' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 403 }
      allow(response).to receive(:body) { '{"message": "Permission denied"}' }

      expect { api.send(:raise_on_failure, response) }.to raise_error(ProxmoxAPI::ApiException) do |error|
        expect(error.message).to eq('HTTP 403 - Permission denied')
        expect(error.response).to eq(response)
      end
    end

    it 'preserves custom error messages when specified' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 401 }
      allow(response).to receive(:body) { '{"message": "Authentication failed"}' }

      expect { api.send(:raise_on_failure, response, 'Custom auth error') }
        .to raise_error(ProxmoxAPI::ApiException) do |error|
        expect(error.message).to eq('HTTP 401 - Authentication failed')
      end
    end
  end
end
