# frozen_string_literal: true

require_relative '../../../../test/test_helper'
require_relative '../bcp_13'



describe Inferno::Terminology::BCP13 do
  it 'should remove optional parameters when semicolon-separated' do
    assert_equal 'application/fhir+json', Inferno::Terminology::BCP13.preprocess_code('application/fhir+json; charset=UTF-8')
  end

  it 'should do nothing with no optional parameters' do
    assert_equal 'application/fhir+json', Inferno::Terminology::BCP13.preprocess_code('application/fhir+json')
  end

  it 'should return MIME types lower-cased' do
    assert_equal 'application/fhir+json', Inferno::Terminology::BCP13.preprocess_code('Application/FHIR+JSON')
  end
end
