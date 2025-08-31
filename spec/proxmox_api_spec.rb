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

  describe 'Error hierarchy' do
    describe 'ProxmoxAPI::Error.from_response' do
      it 'creates BadRequest for 400 status' do
        response = double('Faraday::Response', status: 400, body: '{"message": "Bad request"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::BadRequest)
        expect(error.response).to eq(response)
        expect(error.message).to eq('HTTP 400 - Bad request')
      end

      it 'creates Unauthorized for 401 status' do
        response = double('Faraday::Response', status: 401, body: '{"message": "Authentication failed"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::Unauthorized)
        expect(error.message).to eq('HTTP 401 - Authentication failed')
      end

      it 'creates Forbidden for 403 status' do
        response = double('Faraday::Response', status: 403, body: '{"message": "Permission denied"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::Forbidden)
        expect(error.message).to eq('HTTP 403 - Permission denied')
      end

      it 'creates NotFound for 404 status' do
        response = double('Faraday::Response', status: 404, body: '{"message": "VM not found"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::NotFound)
        expect(error.message).to eq('HTTP 404 - VM not found')
      end

      it 'creates UnprocessableEntity for 422 status' do
        response = double('Faraday::Response',
                          status: 422,
                          body: '{"message": "Invalid parameters", "errors": {"vmid": "required"}}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::UnprocessableEntity)
        expect(error.message).to eq('HTTP 422 - Invalid parameters - (vmid: required)')
      end

      it 'creates InternalServerError for 500 status' do
        response = double('Faraday::Response', status: 500, body: '{"message": "Server error"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::InternalServerError)
        expect(error.message).to eq('HTTP 500 - Server error')
      end

      it 'creates ServiceUnavailable for 503 status' do
        response = double('Faraday::Response', status: 503, body: '{"message": "Service unavailable"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::ServiceUnavailable)
        expect(error.message).to eq('HTTP 503 - Service unavailable')
      end

      it 'creates ClientError for other 4xx status codes' do
        response = double('Faraday::Response', status: 429, body: '{"message": "Too many requests"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::ClientError)
        expect(error).not_to be_a(ProxmoxAPI::ServerError)
      end

      it 'creates ServerError for other 5xx status codes' do
        response = double('Faraday::Response', status: 502, body: '{"message": "Bad gateway"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::ServerError)
        expect(error).not_to be_a(ProxmoxAPI::ClientError)
      end

      it 'creates base Error for non-HTTP error status codes' do
        response = double('Faraday::Response', status: 200, body: '{"message": "Success"}')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::Error)
        expect(error).not_to be_a(ProxmoxAPI::ClientError)
        expect(error).not_to be_a(ProxmoxAPI::ServerError)
      end

      it 'uses custom message when provided' do
        response = double('Faraday::Response', status: 401, body: '{"message": "Authentication failed"}')
        error = ProxmoxAPI::Error.from_response(response, 'Custom auth error')

        expect(error.message).to eq('Custom auth error')
      end

      it 'handles malformed JSON gracefully' do
        response = double('Faraday::Response', status: 400, body: 'invalid json')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::BadRequest)
        expect(error.message).to eq('HTTP 400')
      end

      it 'handles empty response body' do
        response = double('Faraday::Response', status: 404, body: '')
        error = ProxmoxAPI::Error.from_response(response)

        expect(error).to be_a(ProxmoxAPI::NotFound)
        expect(error.message).to eq('HTTP 404')
      end
    end

    describe 'Error hierarchy inheritance' do
      it 'ensures all specific errors inherit from appropriate base classes' do
        expect(ProxmoxAPI::BadRequest.new(nil)).to be_a(ProxmoxAPI::ClientError)
        expect(ProxmoxAPI::Unauthorized.new(nil)).to be_a(ProxmoxAPI::ClientError)
        expect(ProxmoxAPI::Forbidden.new(nil)).to be_a(ProxmoxAPI::ClientError)
        expect(ProxmoxAPI::NotFound.new(nil)).to be_a(ProxmoxAPI::ClientError)
        expect(ProxmoxAPI::UnprocessableEntity.new(nil)).to be_a(ProxmoxAPI::ClientError)

        expect(ProxmoxAPI::InternalServerError.new(nil)).to be_a(ProxmoxAPI::ServerError)
        expect(ProxmoxAPI::ServiceUnavailable.new(nil)).to be_a(ProxmoxAPI::ServerError)

        expect(ProxmoxAPI::ClientError.new(nil)).to be_a(ProxmoxAPI::Error)
        expect(ProxmoxAPI::ServerError.new(nil)).to be_a(ProxmoxAPI::Error)
      end
    end

    describe 'Backward compatibility' do
      it 'maintains ApiException alias' do
        expect(ProxmoxAPI::ApiException).to eq(ProxmoxAPI::Error)
      end

      it 'allows catching with ApiException' do
        response = double('Faraday::Response', status: 400, body: '{"message": "Bad request"}')

        expect do
          raise ProxmoxAPI::Error.from_response(response)
        end.to raise_error(ProxmoxAPI::ApiException)
      end
    end
  end

  describe '#raise_on_failure' do
    it 'does not raise for successful responses' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 200 }

      expect { api.send(:raise_on_failure, response) }.not_to raise_error
    end

    it 'raises specific error class based on status code' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 403 }
      allow(response).to receive(:body) { '{"message": "Permission denied"}' }

      expect { api.send(:raise_on_failure, response) }.to raise_error(ProxmoxAPI::Forbidden) do |error|
        expect(error.message).to eq('HTTP 403 - Permission denied')
        expect(error.response).to eq(response)
      end
    end

    it 'raises error that is also an ApiException for backward compatibility' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 401 }
      allow(response).to receive(:body) { '{"message": "Authentication failed"}' }

      expect { api.send(:raise_on_failure, response) }.to raise_error(ProxmoxAPI::ApiException) do |error|
        expect(error).to be_a(ProxmoxAPI::Unauthorized)
        expect(error.message).to eq('HTTP 401 - Authentication failed')
        expect(error.response).to eq(response)
      end
    end

    it 'uses custom error message when specified' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 401 }
      allow(response).to receive(:body) { '{"message": "Authentication failed"}' }

      expect { api.send(:raise_on_failure, response, 'Custom auth error') }
        .to raise_error(ProxmoxAPI::Unauthorized) do |error|
        expect(error.message).to eq('Custom auth error')
      end
    end

    it 'raises UnprocessableEntity for 422 status with field errors' do
      response = double('Faraday::Response')
      allow(response).to receive(:status) { 422 }
      allow(response).to receive(:body) do
        '{"message": "Parameter verification failed", "errors": {"vmid": "invalid format"}}'
      end

      expect { api.send(:raise_on_failure, response) }.to raise_error(ProxmoxAPI::UnprocessableEntity) do |error|
        expect(error.message).to eq('HTTP 422 - Parameter verification failed - (vmid: invalid format)')
      end
    end
  end
end
