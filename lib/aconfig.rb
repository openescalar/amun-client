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

module Aconfig

  class LoadConfig
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
           Aconnect::queryUrl(:host => "169.254.169.254",:port => 80, :query => "/latest/meta-data/instance-id",:action => :none)
        when "rackspace"
           f = YAML.load_file("/etc/serial")
           f["serial"]
        when "openstack"
           ser = Aconnect::queryUrl(:host => "169.254.169.254",:port => 80,:query => "/latest/meta-data/instance-id",:action => :none)
           ser.gsub(/i\-/,"").to_i(16).to_s
        when "eucalyptus"
           Aconnect::queryUrl(:host => "169.254.169.254",:port => 80,:query => "/latest/meta-data/instance-id",:action => :none)
        else
           f = YAML.load_file("/etc/serial")
           f["serial"]
        end
    end
  end

  @@conf = LoadConfig.new.get
  @@ser = LoadConfig.new.serial(@@conf["location"])

  def self.config
      @@conf
  end
  def self.serial
      @@ser
  end

end
