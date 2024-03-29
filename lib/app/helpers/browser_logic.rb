# frozen_string_literal: true

require 'action_view/helpers/output_safety_helper'
require 'action_view/helpers/capture_helper'
require 'action_view/helpers/javascript_helper'

module Inferno
  class App
    module Helpers
      module BrowserLogic
        include ActionView::Helpers::JavaScriptHelper

        def js_hide_wait_modal
          "<script>console.log('hide_wait_modal');$('#WaitModal').modal('hide');</script>"
        end

        def js_show_test_modal
          "<script>console.log('show_test_modal');$('#testsRunningModal').modal('show')</script>"
        end

        def js_stayalive(time)
          "<script>console.log('Time running: ' + #{time})</script>"
        end

        def js_update_result(instance:, sequence:, test_set:, set_count:, count:, total:)
          cancel_button =
            if sequence.sequence_result
              cancel_link = "#{instance.base_url}#{base_path}/#{instance.id}/test_sets/#{test_set.id}/sequence_result/#{sequence.sequence_result.id}/cancel"
              "<a href=\"#{cancel_link}\" class=\"btn btn-secondary\">Cancel Sequence</a>"
            else
              ''
            end

          %(
            <script>
              $('#testsRunningModal').find('.number-complete:last').html('(#{set_count} of #{sequence.test_count} #{sequence.class.title} tests complete)');
              $('#testsRunningModal .modal-footer').html('#{cancel_button}');
              var progress = Math.round((#{count}/#{total}) * 100);
              console.log('js_update_result (' + progress + ')');
              $('#progress-bar').attr('aria-valuenow', progress).css('width', progress + '%');
            </script>
          )
        end

        def js_redirect(location)
          "<script>console.log('js_redirect'); window.location = '#{location}'</script>"
        end

        def js_redirect_modal(location, expect_redirect_failure, _sequence, instance)
          safe_location = ERB::Util.html_escape(location)
          ok_button = "<a href=\"#{safe_location}\" class=\"btn btn-primary\">Continue</a>"
          warning_text = "Inferno will now redirect you to an external website for user authorization.  For this test sequence to complete successfully, you will need to select a patient and authorize the Inferno client to access their data.  Once you authorize the Inferno client to access patient data, you should be redirected back to Inferno.  If something goes wrong, you can always return to Inferno at <a href=\"#{instance.base_url}#{base_path}/#{instance.id}\">#{instance.base_url}#{base_path}/#{instance.id}</a>.<br/><br/>"

          if expect_redirect_failure
            ok_button = "<a href=\"#{safe_location}\" target=\"_blank\" class=\"btn btn-primary continue_to_confirm\">Perform Invalid Launch in New Window</a><a href=\"#{instance.redirect_uris}?state=#{instance.state}&confirm_fail=true\" class=\"btn btn-primary confirm_to_continue\">Attest Launch Failed</a>"
            warning_text = 'Inferno will redirect you to an external website at the link below for user authorization in a new browser window.  <strong>It is expected this will fail</strong>.  If the server does not return to Inferno automatically, but does provide an error message, you may return to Inferno and confirm that an error was presented in this window.<br/><br/>'
          end

          "<script>console.log('js_redirect_modal');$('#testsRunningModal').find('.modal-body').html('#{warning_text} <textarea readonly class=\"form-control\" rows=\"3\">#{escape_javascript(safe_location)}</textarea>'); $('#testsRunningModal').find('.modal-footer').append('#{escape_javascript(ok_button)}');</script>"
        end

        def js_next_sequence(sequences)
          # "<script>console.log('js_next_sequence');$('#testsRunningModal').find('.number-complete-container').append('<div class=\'number-complete\'></div>');</script>"
        end

        def markdown_to_html(markdown)
          # we need to remove the 'normal' level of indentation before passing to markdown editor
          # find the minimum non-zero spacing indent and reduce by that many for all lines (note, did't make work for tabs)
          natural_indent = markdown.lines.collect { |l| l.index(/[^ ]/) }.select { |l| !l.nil? && l.positive? }.min || 0
          unindented_markdown = markdown.lines.map { |l| l[natural_indent..-1] || "\n" }.join
          html = Kramdown::Document.new(unindented_markdown, link_attributes: { target: '_blank' }).to_html

          # custom updates
          html.gsub!('<table>', '<table class="table">')

          html
        end
      end
    end
  end
end
