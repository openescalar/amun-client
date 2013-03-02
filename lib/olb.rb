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

module Olb

  @@confok = true
  
  def self.task(m,serial,config,content)

        p = Hash.new
        p["olb"]	= serial
        p["action"]     = "get"
        p["key"]	= config["key"]
        p["location"]	= config["location"]

        q = Aencrypt::encrypt(p,config["secret"])

        Alog::log("Requesting server info from to Api server")

        r = Aconnect::queryUrl(:query => q,:action => :olb)

        p = Hash.new
        p["action"]	= "update"
        p["key"]	= config["key"]
        p["ident"]      = content["ident"]

        Alog::log("Executing " + content["action"])

	self.config

        p["code"], p["output"] = self.reload

        Alog::log("Task execution finished")

        q = Aencrypt::encrypt(p,config["secret"])

        Aconnect::queryUrl(:query => q,:action => :event)
  end

  def self.metadata(content,serial,config)
    ""
  end

  def self.build
    begin
      %x[yum install -y nginx haproxy]
      self.start
    rescue
      Alog::log("Couldn't install OLB packages")
    end
  end

  def self.config
    begin
      File.open("/etc/haproxy/haproxy.cfg",'w') {|f| f.write(ERB.new(File.new("/opt/openescalar/amun-client/lib/olbdef.erb").read, nil, "%").result(binding))}
      File.open("/etc/nginx/conf.d/ssl.conf",'w') {|f| f.write(ERB.new(File.new("/opt/openescalar/amun-client/lib/olbcer.erb").read, nil, "%").result(binding))}
      @@confok = true
    rescue 
      @@confok = false
      Alog::log("Error while creating configuration files")
    end
  end

  def self.start
    begin
      %x[/etc/init.d/nginx start]
      %x[/etc/init.d/haproxy start]
    rescue
      Alog::log("Error starting OLB")
    end
  end

  def self.stop
    begin
      %x[/etc/init.d/haproxy stop]
      %x[/etc/init.d/nginx stop]
    rescue
      Alog::log("Error stopping OLB")
    end
  end

  def self.reload
    begin
      raise if not @@confok
      %x[/etc/init.d/haproxy reload]
      %x[/etc/init.d/nginx reload]
      0, "Changes Applied"
    rescue
      Alog::log("Error Reloading OLB")
      1, "Error while applying changes"
    end
  end

end

