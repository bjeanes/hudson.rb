Given /^I have a Hudson server running$/ do
  unless @hudson_port
    port = 3010
    begin
      res = Net::HTTP.start("localhost", port) { |http| http.get('/api/json') }
    rescue Errno::ECONNREFUSED => e
      puts "\n\n\nERROR: To run tests, launch hudson in test mode: 'rake hudson:server:test'\n\n\n"
      exit
    end
    @hudson_port = port.to_s
    @hudson_host = 'localhost'
  end
end

Given /^the Hudson server has no current jobs$/ do
  if port = @hudson_port
    require "open-uri"
    require "yajl"
    hudson_info = Yajl::Parser.new.parse(open("http://#{@hudson_host}:#{@hudson_port}/api/json"))

    hudson_info['jobs'].each do |job|
      job_url = job['url']
      res = Net::HTTP.start("localhost", port) { |http| http.post("#{job_url}doDelete/api/json", {}) }
    end
    hudson_info = Yajl::Parser.new.parse(open("http://#{@hudson_host}:#{@hudson_port}/api/json"))
    hudson_info['jobs'].should == []
  else
    puts "WARNING: Run 'I have a Hudson server running' step first."
  end
end

Given /^the Hudson server has no slaves$/ do
  if port = @hudson_port
    require "open-uri"
    require "yajl"
    base_url    = "http://#{@hudson_host}:#{@hudson_port}"
    hudson_info = Yajl::Parser.new.parse(open("#{base_url}/computer/api/json"))

    hudson_info['computer'].each do |node|
      name = node["displayName"]
      next if name == "master"
      job_url = "#{base_url}/computer/#{CGI::escape(name).gsub('+', '%20')}"
      res = Net::HTTP.start("localhost", port) { |http| http.post("#{job_url}/doDelete/api/json", {}) }
    end
    hudson_info = Yajl::Parser.new.parse(open("http://#{base_url}/computes/api/json"))
    hudson_info['computer'].should have(1).item
  else
    puts "WARNING: Run 'I have a Hudson server running' step first."
  end
end

Given /^managing the Hudson server requires authenticating$/ do
  if port = @hudson_port
    require "fileutils"

    @hudson_home = "/tmp/test_hudson"
    @user_dir    = "#{@hudson_home}/admin"
    fixtures     = File.join(File.dirname(__FILE__), "..", "fixtures")

    FileUtils.mkdir_p(@user_dir)
    FileUtils.cp(File.join(fixtures, "user.config.xml"),           File.join(@user_dir, "config.xml"))
    FileUtils.cp(File.join(fixtures, "authentication.config.xml"), File.join(@hudson_home, "config.xml"))

    Net::HTTP.start("localhost", port) do |http|
      req = Net::HTTP::Post.new("/reload/api/json")
      http.request(req)
    end

    Net::HTTP.start("localhost", port) do |http|
      sleep 1 while http.get("/").body =~ /Please wait while Hudson is getting ready to work/
    end
  else
    puts "WARNING: Run 'I have a Hudson server running' step first."
  end
end


Given /^there is nothing listening on port (\d+)$/ do |port|
  lambda {
    TCPSocket.open("localhost", port) {}
  }.should raise_error
end

Given /^I cleanup any hudson processes with control port (\d+)$/ do |port|
  @hudson_cleanup << port
end

def try(times, interval = 1)
  begin
    times -= 1
    return yield
  rescue Exception => e
    if times >= 0
      sleep(interval)
      retry
    end
    raise e
  end
end

When /^I run hudson server with arguments "(.*)"/ do |arguments|
  @stdout = File.expand_path(File.join(@tmp_root, "executable.out"))
  executable = File.expand_path(File.join(File.dirname(__FILE__), "/../../bin","hudson"))
  in_project_folder do
    system "ruby #{executable.inspect} server #{arguments} > #{@stdout.inspect} 2> #{@stdout.inspect}"
  end
end


Then /^I should see a hudson server on port (\d+)$/ do |port|
  require 'json'
  try(15, 2) do
    res = Net::HTTP.start("localhost", port) { |http| http.get('/api/json') }
    JSON.parse(res.body)['nodeDescription'].should == "the master Hudson node"
  end
end

