# frozen_string_literal: true

require 'rest_client'
require 'uri'
require 'nokogiri'

module Inferno
  # NLMUserValidator submits an api key to the NLM API, and tests whether the returned value is valid
  class NLMUserValidator
    TGT_URL = 'https://utslogin.nlm.nih.gov/cas/v1/api-key'
    TICKET_URL = 'https://utslogin.nlm.nih.gov/cas/v1/tickets/'
    SERVICE_VALIDATE_URL = 'https://utslogin.nlm.nih.gov/cas/serviceValidate'

    def self.proxy_ticket(api_key)
      output = Nokogiri::HTML(RestClient.post(TGT_URL, apikey: api_key))
      output&.at('form')&.attribute('action')&.value&.split('/')&.last
    end

    def self.service_ticket(api_key)
      RestClient.post("#{TICKET_URL}/#{proxy_ticket(api_key)}", service: 'http://umlsks.nlm.nih.gov')&.body
    end

    def self.validate_ticket(ticket)
      output = Nokogiri::XML(RestClient.get("#{SERVICE_VALIDATE_URL}?ticket=#{ticket}&service=http://umlsks.nlm.nih.gov"))
      output&.at_xpath('/cas:serviceResponse/cas:authenticationSuccess/cas:user')&.content&.present?
    rescue StandardError
      false
    end
  end
end
