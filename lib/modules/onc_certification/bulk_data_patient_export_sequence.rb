# frozen_string_literal: true

require_relative 'bulk_data_export_sequence'

module Inferno
  module Sequence
    class BulkDataPatientExportSequence < BulkDataExportSequence
      extends_sequence BulkDataExportSequence

      group 'Bulk Data Patient Export'

      title 'Patient Compartment Export Tests'

      description 'Verify that patient compartment export on the Bulk Data server follows the Bulk Data Access Implementation Guide'

      test_id_prefix 'Patient'

      requires :bulk_access_token, :bulk_lines_to_validate
      conformance_supports :Patient

      def endpoint
        'Patient'
      end
    end
  end
end
