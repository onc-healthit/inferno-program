# frozen_string_literal: true

require_relative '../utils/result_statuses'
require_relative '../utils/logging'

module Inferno
  module Models
    class SequenceResult
      include ResultStatuses
      include DataMapper::Resource
      property :id, String, key: true, default: proc { SecureRandom.uuid }
      property :name, String
      property :result, String
      property :test_case_id, Text
      property :test_set_id, Text

      property :redirect_to_url, Text
      property :wait_at_endpoint, Text
      property :expect_redirect_failure, Boolean, default: false

      property :required_passed, Integer, default: 0
      property :required_total, Integer, default: 0
      property :error_count, Integer, default: 0
      property :todo_count, Integer, default: 0
      property :skip_count, Integer, default: 0
      property :optional_passed, Integer, default: 0
      property :optional_total, Integer, default: 0
      property :required_omitted, Integer, default: 0
      property :optional_omitted, Integer, default: 0

      property :app_version, String

      property :required, Boolean, default: true
      property :input_params, Text
      property :output_results, Text

      property :next_sequences, Text
      property :next_test_cases, Text

      property :created_at, DateTime, default: proc { DateTime.now }

      has n, :test_results, order: [:test_index.asc]
      belongs_to :testing_instance

      def self.recent_results_for_iss(iss)
        all(
          :created_at.gte => 5.minutes.ago,
          :result => 'wait',
          :order => [:created_at.desc]
        ).find { |result| normalize_url(result.testing_instance.url) == normalize_url(iss) }
      end

      def failures
        test_results.select(&:fail?)
      end

      def reset!
        [
          'required_passed',
          'required_total',
          'error_count',
          'todo_count',
          'skip_count',
          'optional_passed',
          'optional_total',
          'required_omitted',
          'optional_omitted'
        ].each { |field| send("#{field}=", 0) }
      end

      def result_count
        test_results.length
      end

      def total_omitted
        required_omitted + optional_omitted
      end

      def total_required_tests_except_omitted
        required_total - required_omitted
      end

      def update_result_counts
        test_results.each do |result|
          if result.required
            self.required_total += 1
          else
            self.optional_total += 1
          end
          case result.result
          when ResultStatuses::PASS
            if result.required
              self.required_passed += 1
            else
              self.optional_passed += 1
            end
            self.result = result.result unless error? || fail? || skip?
          when ResultStatuses::OMIT
            if result.required
              self.required_omitted += 1
            else
              self.optional_omitted += 1
            end
          when ResultStatuses::TODO
            self.todo_count += 1
          when ResultStatuses::FAIL
            if result.required
              self.result = result.result unless error?
            end
          when ResultStatuses::ERROR
            if result.required
              self.error_count += 1
              self.result = result.result
            end
          when ResultStatuses::SKIP
            if result.required
              self.result = result.result if pass? || self.result.nil?
              self.skip_count += 1
            end
          when ResultStatuses::WAIT
            self.result = result.result
          end
        end
        self.result = ResultStatuses::PASS if self.result.nil?
      end

      def self.normalize_url(url)
        url&.downcase&.split('://')&.last&.chomp('/')
      end
      private_class_method :normalize_url
    end
  end
end
