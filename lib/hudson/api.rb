require 'httparty'
require 'cgi'

module Hudson
  class Api
    include HTTParty

    headers 'content-type' => 'application/json'
    format :json

    def self.setup_base_url(host, port)
      base_uri "http://#{host}:#{port}"
    end
    
    def self.create_job(name, job_config)
      self.post("/createItem/api/json?name=#{CGI.escape(name)}", {
        :body => job_config.to_xml,
      })
    end
    
  end
end