# frozen_string_literal: true

module Inferno
  class App
    module OAuth2ErrorMessages
      def no_instance_for_state_error_message
        %(
          <p>
            Inferno has detected an issue with the SMART launch.
            #{param_description}
            The authorization server is not returning the correct state variable and
            therefore Inferno cannot identify which server is currently under test.
            Please click your browser's "Back" button to return to Inferno,
            and click "Refresh" to ensure that the most recent test results are visible.
          </p>
          #{server_error_message}
          #{server_error_description}
        )
      end

      def param_description
        return "No 'state' parameter was returned by the authorization server." if params[:state].nil?

        "No actively running launch sequences found with a 'state' parameter of '#{ERB::Util.html_escape(params[:state])}'."
      end

      def server_error_message
        return '' if params[:error].blank?

        "<p>Error returned by server: <strong>#{ERB::Util.html_escape(params[:error])}</strong>.</p>"
      end

      def server_error_description
        return '' if params[:error_description].blank?

        "<p>Error description returned by server: <strong>#{ERB::Util.html_escape(params[:error_description])}</strong>.</p>"
      end

      def bad_state_error_message
        "State provided in redirect (#{ERB::Util.html_escape(params[:state])}) does not match expected state (#{ERB::Util.html_escape(@instance.state)})."
      end

      def no_instance_for_iss_error_message
        %(
          Error: No actively running launch sequences found for iss #{ERB::Util.html_escape(params[:iss])}.
          Please ensure that the EHR launch test is actively running before attempting to launch Inferno from the EHR.
        )
      end

      def unknown_iss_error_message
        params[:iss].present? ? "Unknown iss: #{ERB::Util.html_escape(params[:iss])}" : no_iss_error_message
      end

      def no_iss_error_message
        'No iss querystring parameter provided to launch uri'
      end

      def no_running_test_error_message
        'Error: Could not find a running test that matches this set of criteria'
      end
    end
  end
end
