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
require './aconfig.rb'
require './aconnect.rb'
require './alog.rb'
require './aencrypt.rb'
require './oclient.rb'
require './ovpn.rb'
require './olb.rb'

class Oeclient

  def initialize
    @loop = true
    @queue = "/topic/openescalar"
    @config = Aconfig::config
    case @config["mode"]
       when "olb"
         extend Olb
       when "ovpn"
         extend Ovpn
       else 
         extend Oclient
    end
  end

  def start
    begin
      @loop = true
      @serial = Aconfig::serial
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
      self.build
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
	      m	= self.metadata(content,@serial,@config)
	      self.task(m,@serial,@config,content)
            else
              Alog::log("AmunClient - Message doesnt match server serial")
            end
          else
            Alog::log("AmunClient - No messages for this server")
          end 
          if not c.client_ack?(msg)
            c.ack(msg.headers["message-id"]) if content["server"].to_s == @serial.to_s
          end
        end
      end
      begin
        c.disconnect 
      rescue
        Alog::log("AmunClient - Error while disconnecting from queue server")
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
        q = Aencrypt::encrypt(p,@config["secret"])
        begin
	    Aconnect::queryUrl(:query => q,:action => :ping)
        rescue
            Alog::log("AmunClient - Error while pinging OpenEscalar")
        end
        sleep 300
      end
    end  
  end

end
