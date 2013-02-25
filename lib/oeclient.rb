#!/usr/bin/env ruby
#
# Copyright 2012 Miguel Zuniga <miguelzuniga@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if RUBY_VERSION.to_f <= 1.8
  require 'rubygems'
end
require 'openssl'
require 'base64'
require 'stomp'
require 'yaml'
require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'
require 'time'
require 'syslog'
require 'securerandom'
require 'erb'
require 'fileutils'

module Olb
end

module Ovpn
end

module Oclient

   def self.build
      if not File.exists?('/opt/openescalar/amun-client/conf/reboot')
        p = Hash.new
        p["server"] = Aconfig::serial
        p["action"] = "build"
        p["key"]    = Aconfig::config["key"]
        p["location"] = Aconfig::config["location"]
        Alog::log("AmunClient - Requesting buildscript")
        q = Aencrypt::encrypt(p,Aconfig::config["secret"])
        Aconnect::queryUrl(Aconfig::config["oeapiserver"], Aconfig::config["oeapiport"],q,:builder)
        FileUtils.touch("/opt/openescalar/amun-client/conf/reboot")
      end
    end

    def self.metadata(content,serial,config)
        if not content["metadata"].nil?
           Alog::log("AmunClient - Task will be executed with metadata")
        else
           Alog::log("AmunClient - Task will be executed without metadata")
        end
        if not content["metadata"].nil?
	   p = Hash.new
           p["server"] 		= serial
           p["action"]       	= "download"
	   p["key"]		= config["key"]
	   p["location"]	= config["location"]
           case content["metadata"].to_s
	      when "deployment"
		 p["type"]		= "deployment"
                 p["deployment"]	= content["deployment"]
                 Alog::log("AmunClient - Task will require deployment metadata")
	      when "role"
		 p["type"]		= "role"
                 p["role"]		= content["role"]
                 Alog::log("AmunClient - Task will require role metadata")
           end
           q = Aencrypt::encrypt(p,s)
           Alog::log("AmunClient - Requesting metadata to Api server")
	   Aconnect::queryUrl(config["oeapiserver"],config["oeapiport"],q,:getmeta)
        end
    end

    def self.task(m,serial,config,content)
        p = Hash.new
        p["server"]	= serial
        p["action"]     = "gettask"
        p["task"]	= content["task"]
        p["key"]	= config["key"]
        p["location"]	= config["location"]
        q = Aencrypt::encrypt(p,s)
        Alog::log("AmunClient - Requesting task from to Api server")
        r = Aconnect::queryUrl(q,:querytask)
        p = Hash.new
        p["action"]	= "updatetask"
        p["key"]	= config["key"]
        p["ident"]      = content["ident"]
        Alog::log("AmunClient - Executing task " + content["task"])
        p["code"], p["output"] = self.executeTask(r,p["ident"],m)
        Alog::log("AmunClient - Task execution finished")
        q = Aencrypt::encrypt(p,s)
        Alog::log("AmunClient - Updating Status Event")
        Aconnect::queryUrl(q,:querytask)
    end

    def self.executeTask(resp,ident,meta)
      type = "script"
      if resp.code.to_i == 200
        if not File.directory? "/tmp/amun-client"
          Dir::mkdir("/tmp/amun-client")
        end
        metafile = "/tmp/amun-client/meta-" + ident
        open(metafile,"w") { |f|
          f.write(CGI.unescapeHTML(meta.body).gsub!("\015",""))
        }
        Alog::log("AmunClient - Created metadata file")
        tfile = "/tmp/amun-client/" + ident
        open(tfile,"w") { |f|
          f.write(CGI.unescapeHTML(resp.body).gsub!("\015",""))
        }
        Alog::log("AmunClient - Created task file")
        File.chmod(0755,metafile)
        File.chmod(0755,tfile)
        output = ""
        pid = ""
        ecode = ""
        case type
          when "puppet"
             output = %x[puppet apply #{tfile} 2>&1]
             pid = $?.pid
             ecode = $?.exitstatus
          when "chef"
             output = %x[chef-solo #{tfile} 2>&1]
             pid = $?.pid
             ecode = $?.exitstatus
          when "script"
             output = %x[source #{metafile} ; #{tfile} 2>&1]
             pid = $?.pid
             ecode = $?.exitstatus
          else
             output = %x[source #{metafile} ; #{tfile} 2>&1]
             pid = $?.pid
             ecode = $?.exitstatus
        end
        return ecode, output
      end
    end
end

module Aconnect
  def self.queryUrl(host,port,query,action)
    case action
       when :pingme
          path = "/pingme?#{query}"
       when :querytask
          path = "/task?#{query}"
       when :getmeta
          path = "/metadata?#{query}"
       when :builder
          path = "/builder?#{query}"
       when :vote
          path = "/escalar?#{query}"
       else 
          path = query
    end
    begin
      sock = Net::HTTP.new(host,port)
      resp = sock.get(path)
      resp.body
    rescue
      Alog::log("AmunClient - Error while connecting to Api server")
    end
  end
end

module Aencrypt
  def self.encrypt(parameters,secret)
    parameters["time"] 		= Time.now.utc.iso8601
    canonical_querystring 	= parameters.sort.collect { |key,value| [URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")), URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))].join('=') }.join('&')
    hmac 			= OpenSSL::HMAC.new(secret,'sha256')
    hmac.update(canonical_querystring)
    signature 			= Base64.encode64(hmac.digest).chomp
    parameters['signature'] 	= signature
    querystring 		= parameters.sort.collect { |key,value| [URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")), URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))].join('=') }.join('&')
    querystring
  end
end

module Alog
  def self.log(message)
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.warning message }
  end
end

module Aconfig

  @@conf = Config.new.get
  @@ser = Config.new.serial(@@conf["location"])

  def self.config
      @@conf
  end
  def self.serial
      @@ser
  end

  class Config
    def get
      begin
        YAML.load_file('/opt/openescalar/amun-client/conf/client.conf')["client"]
      rescue
        Alog::log("Error reading client configuration file")
      end
    end

    def serial(loc)
      case loc
        when "ec2"
           Aconnect::queryUrl("169.254.169.254",80,"/latest/meta-data/instance-id",:none)
        when "rackspace"
           f = YAML.load_file("/etc/serial")
           f["serial"]
        when "openstack"
           ser = Aconnect::queryUrl("169.254.169.254",80,"/latest/meta-data/instance-id",:none)
           ser.gsub(/i\-/,"").to_i(16).to_s
        when "eucalyptus"
           Aconnect::queryUrl("169.254.169.254",80,"/latest/meta-data/instance-id",:none)
        else
           f = YAML.load_file("/etc/serial")
           f["serial"]
        end
    end
  end
end

class Oeclient

  def initialize
    @loop = true
    @queue = "/topic/openescalar"
    @config = Aconfig::config
  end

  def start
    begin
      @loop = true
      @serial = Aconfig::serial(@config["location"])
      mainListen
      pinger
      Alog::log("AmunClient - STARTING")
    rescue
      Alog::log("AmunClient - Error while connecting to OpenEscalar Queue Server")
    end
  end

  def stop
    @loop = false
    begin
      @t.kill
      @t2.kill
      Alog::log("AmunClient - SHUTDOWN")
    rescue
      Alog::log("AmunClient - Error while stopping client")
    end
  end



private 

  def mainListen
    @t = Thread.new do
      begin
        c = Stomp::Connection.new(login = @config["oequser"], password = @config["oeqpass"], host = @config["oeserver"], port = @config["oeport"], reliable = false, reconnect_delay=5 )
        c.subscribe @queue, { :ack => :client }
        Alog::log("AmunClient - Connected to queue server")
      rescue
        Alog::log("AmunClient - Error while connecting to queue server")
      end
      Oeclient::build
      while @loop
        begin
          msg = c.receive
          Alog::log("AmunClient - received msg for #{@serial}")
        rescue
          Alog::log("AmunClient - Unable to receive msg from queue")
        end
        sleep 1
        if msg
          content = YAML.load(msg.body)
          if not content.nil?
            Alog::log("AmunClient - Got task " + content["task"] )
            if content["server"].to_s == @serial.to_s
	      s	= @config["secret"]
	      m	= Oclient::metadata(content,@serial,@config)
	      Oclient::task(m,@serial,@config,content)
            else
              log("AmunClient - Message doesnt match server serial")
            end
          else
            log("AmunClient - No messages for this server")
          end 
          if not c.client_ack?(msg)
            c.ack(msg.headers["message-id"]) if content["server"].to_s == @serial.to_s
          end
        end
      end
      begin
        c.disconnect 
      rescue
        log("AmunClient - Error while disconnecting from queue server")
      end
    end
  end

  def pinger
    @t2 = Thread.new do
      while @loop
        p = Hash.new
        p["action"]             = "ping"
        p["key"]                = @config["key"]
        p["server"]             = @serial
        q = encrypt(p,@config["secret"])
        begin
            pingMe(q)
        rescue
            Alog::log("AmunClient - Error while pinging OpenEscalar")
        end
        sleep 300
      end
    end  
  end

end
