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

module Ovpn

  @@confok = true

  def self.task(m,serial,config,content)

        p = Hash.new
        p["server"]	= serial
        p["action"]     = "get"
        p["key"]	= config["key"]
        p["location"]	= config["location"]

        q = Aencrypt::encrypt(p,config["secret"])

        Alog::log("Requesting task from to Api server")

        r = Aconnect::queryUrl(:query => q,:action => :ovpn)

        p = Hash.new
        p["action"]	= "update"
        p["key"]	= config["key"]
        p["ident"]      = content["ident"]

        Alog::log("Executing task " + content["task"])

        case content["action"]
           when "connect"
              self.config
              p["code"], p["output"] = self.connect
           when "disconnect"
              self.disconnect
        end

        Alog::log("Task execution finished")

        q = Aencrypt::encrypt(p,config["secret"])

        Aconnect::queryUrl(:query => q, :action => :event)
  end

  def self.metadata(content,serial,config)
    ""
  end

  def self.build
    begin
      %x[yum install -y openvpn]
      self.start
    rescue
      Alog::log("Couldn't install OLB packages")
    end
  end

  def self.config
    begin
      File.open("/etc/openvpn/openvpn.conf",'w') {|f| f.write(ERB.new(File.new("/opt/openescalar/amun-client/lib/ovpndef.erb").read, nil, "%").result(binding))}
      @@confok = true
    rescue 
      @@confok = false
      Alog::log("Error while creating configuration files")
    end
  end
 
  def self.connect
    begin
      raise if not @@confok
      %x[/etc/init.d/openvpn start]
      0, "Connected"
    rescue
      Alog::log("Error while connecting to vpc")
      1, "Not connected"
    end
  end

  def self.disconnect
    begin
      %x[/etc/init.d/openvpn stop]
    rescue
      Alog::log("Error while disconnecting from vpc")
    end
  end

end

