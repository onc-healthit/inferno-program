# frozen_string_literal: true

module Inferno
  module Models
    class RequestResponse
      include DataMapper::Resource
      property :id, String, key: true, default: proc { SecureRandom.uuid }
      property :request_method, String
      property :request_url, String, length: 500
      property :request_headers, String, length: 1000
      property :request_payload, Text
      property :response_code, Integer
      property :response_headers, String, length: 1000
      property :response_body, Text
      property :direction, String
      property :instance_id, String
      property :request_index, Serial, unique_index: true, key: false

      property :timestamp, DateTime, default: proc { DateTime.now }

      has n, :test_results, through: Resource

      def self.from_request(req, instance_id, direction = nil)
        request = req.request
        response = req.response

        escaped_body = response[:body].dup # In case body is frozen from string literal
        unescape_unicode(escaped_body)

        new(
          direction: direction || req&.direction,
          request_method: request[:method],
          request_url: request[:url],
          request_headers: request[:headers].to_json,
          request_payload: request[:payload],
          response_code: response[:code],
          response_headers: response[:headers].to_json,
          response_body: escaped_body,
          instance_id: instance_id,
          timestamp: response[:timestamp]
        )
      end

      # This is needed to escape HTML when the html tags are unicode escape sequences
      # https://stackoverflow.com/questions/7015778/is-this-the-best-way-to-unescape-unicode-escape-sequences-in-ruby
      def self.unescape_unicode(body)
        body.gsub!(/\\u(\h{4})/) { |_m| [Regexp.last_match(1)].pack('H*').unpack('n*').pack('U*') }
      end
    end
  end
end
