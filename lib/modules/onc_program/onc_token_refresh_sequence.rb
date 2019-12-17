# frozen_string_literal: true

require_relative '../smart/token_refresh_sequence'
require_relative './shared_onc_launch_tests'

module Inferno
  module Sequence
    class ONCTokenRefreshSequence < TokenRefreshSequence
      extends_sequence TokenRefreshSequence
      include Inferno::Sequence::SharedONCLaunchTests

      title 'Token Refresh'
      test_id_prefix 'OTR'

      patient_context_test(index: '05', refresh: true)

      encounter_context_test(index: '06', refresh: true)
    end
  end
end
