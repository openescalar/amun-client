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
require 'socket'
require '/opt/openescalar/amun-client/lib/aconfig.rb'
require '/opt/openescalar/amun-client/lib/aconnect.rb'
require '/opt/openescalar/amun-client/lib/alog.rb'
require '/opt/openescalar/amun-client/lib/aencrypt.rb'

class Horus

  def initialize
    @loop = true
    @config = Aconfig::config
  end

  def start
    begin
      @loop = true
      @serial = Aconfig::serial
      mainListen
      Alog::log("STARTING")
    rescue
      Alog::log("Error starting listener")
    end
  end

  def stop
    @loop = false
    begin
      @t.kill
      Alog::log("SHUTDOWN")
    rescue
      Alog::log("Error while stopping listener")
    end
  end



private 

  def mainListen
    @t = Thread.new do
      begin
        h = TCPServer.open('127.0.0.1',6868)
      rescue
        Alog::log("Error opening socket to 127.0.0.1:6868")
      end
      while @loop
        Thread.start(h.accept) do |client|
          client.puts "Horus Listener #{Time.now.ctime}"
          a = true
          while a
            d = client.gets.chop
            if d
               Alog::log("Message #{d}")
               if d.to_s == "EOM"
               #Scale here
                 p = Hash.new
                 p["server"]		= @serial
		 p["action"]		= "create"
		 p["key"]		= @config["key"]
		 p["location"]		= @config["location"]
		 q = Aencrypt::encrypt(p, @config["secret"])
                 Aconnect::queryUrl(:query => q, :action => :escalar)
                 a = false
               end
            end
          end
          client.close
        end
      end
      begin
        h.close
      rescue
        Alog::log("Error closing socket on 127.0.0.1:6868")
      end
    end
  end

end
