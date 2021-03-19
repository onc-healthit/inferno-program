# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/app/models/testing_instance'
require_relative '../../lib/app/models/sequence_result'
require_relative '../../lib/app/models/test_result'

describe Inferno::Models::RequestResponse do
  before do
    @instance = Inferno::Models::TestingInstance.create(selected_module: 'uscore_v3.1.1')
    @instance_id = @instance.id
    @sequence_result = Inferno::Models::SequenceResult.create(testing_instance: @instance)
    @result = Inferno::Models::TestResult.new(sequence_result: @sequence_result)
    @result.save!
  end
  it 'returns the request and responses in the correct order' do
    10.times do |index|
      @result.request_responses << Inferno::Models::RequestResponse.create(
        request_url: "http://#{index}"
      )
      @result.save!
    end

    instance = Inferno::Models::TestingInstance.get(@instance_id)
    result = instance.sequence_results.first.test_results.first
    result.request_responses.each_with_index do |request_response, index|
      assert_equal request_response.request_url, "http://#{index}"
    end
  end
end
