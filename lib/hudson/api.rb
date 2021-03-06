require 'httparty'
require 'cgi'
require 'uri'
require 'json'

module Hudson
  module Api
    include HTTParty

    headers 'content-type' => 'application/json'
    format :json
    # http_proxy 'localhost', '8888'

    def self.setup_base_url(options)
      # Thor's HashWithIndifferentAccess is based on string keys which URI::HTTP.build ignores
      options = options.inject({}) { |mem, (key, val)| mem[key.to_sym] = val; mem }
      options[:host] ||= ENV['HUDSON_HOST']
      options[:port] ||= ENV['HUDSON_PORT']
      options[:port] &&= options[:port].to_i
      return false unless options[:host] || Hudson::Config.config["base_uri"]
      uri = options[:host] ? URI::HTTP.build(options) : Hudson::Config.config["base_uri"]
      base_uri uri.to_s
      uri
    end

    # returns true if successfully create a new job on Hudson
    def self.create_job(name, job_config)
      res = post "/createItem/api/xml?name=#{CGI.escape(name)}", {
        :body => job_config.to_xml, :format => :xml, :headers => { 'content-type' => 'application/xml' }
      }
      if res.code == 200
        cache_base_uri
        true
      else
        require "hpricot"
        puts "Server error:"
        puts Hpricot(res.body).search("//body").text
        false
      end
    end

    def self.summary
      begin
        json = get "/api/json"
        cache_base_uri
        json
      rescue Errno::ECONNREFUSED => e
        false
      end
    end

    # Return hash of job statuses
    def self.job(name)
      begin
        json = get "/job/#{name}/api/json"
        cache_base_uri
        json
      rescue Errno::ECONNREFUSED => e
        false
      end
    end

    def self.nodes
      json = get "/computer/api/json"
      cache_base_uri
      json
    rescue Errno::ECONNREFUSED => e
      false
    end

    # Adds SSH nodes only, for now
    def self.add_node(options = {})
      default_options = Hash.new("")
      default_options.merge!(
        :slave_port  => 22,
        :master_key  => "/home/hudson/.ssh/hudson",
        :remote_fs   => "/data/hudson-slave/",
        :description => "Automatically created by Hudson.rb",
        :executors   => 2,
        :exclusive   => true
      )

      options = default_options.merge(options)

      name = options[:name]
      type = "hudson.slaves.DumbSlave$DescriptorImpl"

      fields = {
        "name" => name,
        "type" => type,

        "json"                => {
          "name"              => name,
          "nodeDescription"   => options[:description],
          "numExecutors"      => options[:executors],
          "remoteFS"          => options[:remote_fs],
          "labelString"       => options[:label],
          "mode"              => options[:exclusive] ? "EXCLUSIVE" : "NORMAL",
          "type"              => type,
          "retentionStrategy" => { "stapler-class"  => "hudson.slaves.RetentionStrategy$Always" },
          "nodeProperties"    => { "stapler-class-bag" => "true" },
          "launcher"          => {
            "stapler-class" => "hudson.plugins.sshslaves.SSHLauncher",
            "host"          => options[:slave_host],
            "username"      => options[:slave_user],
            "privatekey"    => options[:master_key],
            "port"          => options[:slave_port]
          }
        }.to_json
      }

      url = URI.parse("#{base_uri}/computer/doCreateItem")
      req = Net::HTTP::Post.new(url.path)
      req.set_form_data(fields)

      http = Net::HTTP.new(url.host, url.port)

      case http.request(req)
      when Net::HTTPFound
        true
      else
        false
      end
    end

    private
    def self.cache_base_uri
      Hudson::Config.config["base_uri"] = base_uri
      Hudson::Config.store!
    end
  end
end
