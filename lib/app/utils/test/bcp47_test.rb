# frozen_string_literal: true

require_relative '../../../../test/test_helper'
require_relative '../bcp47'

describe Inferno::BCP47 do
  before do
    @bcp47 = Inferno::BCP47
  end
  it 'can load all languages' do
    @bcp47.filter_codes.length == 8152
  end
end
