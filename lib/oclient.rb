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

module Oclient

   def self.build
      if not File.exists?('/opt/openescalar/amun-client/conf/reboot')

        p = Hash.new
        p["server"] = Aconfig::serial
        p["action"] = "build"
        p["key"]    = Aconfig::config["key"]
        p["location"] = Aconfig::config["location"]

        Alog::log("Requesting buildscript")

        q = Aencrypt::encrypt(p,Aconfig::config["secret"])

        Aconnect::queryUrl(:query => q,:action => :task)

        FileUtils.touch("/opt/openescalar/amun-client/conf/reboot")
      end
    end

    def self.metadata(content,serial,config)

        if not content["metadata"].nil?
           Alog::log("Task will be executed with metadata")
        else
           Alog::log("Task will be executed without metadata")
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
                 Alog::log("Task will require deployment metadata")
	      when "role"
		 p["type"]		= "role"
                 p["role"]		= content["role"]
                 Alog::log("Task will require role metadata")
           end

           q = Aencrypt::encrypt(p,config["secret"])

           Alog::log("Requesting metadata to Api server")

	   Aconnect::queryUrl(:query => q, :action => :meta)

        end
    end

    def self.task(m,serial,config,content)

        p = Hash.new
        p["server"]	= serial
        p["action"]     = "get"
        p["task"]	= content["task"]
        p["key"]	= config["key"]
        p["location"]	= config["location"]

        q = Aencrypt::encrypt(p,config["secret"])

        Alog::log("Requesting task from to Api server")

        r = Aconnect::queryUrl(:query => q,:action => :task)

        p = Hash.new
        p["action"]	= "update"
        p["key"]	= config["key"]
        p["ident"]      = content["ident"]

        Alog::log("Executing task " + content["task"])

        p["code"], p["output"] = self.executeTask(r,p["ident"],m)

        Alog::log("Task execution finished")

        q = Aencrypt::encrypt(p,config["secret"])

        Alog::log("Updating Status Event")

        Aconnect::queryUrl(:query => q, :action => :event)

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
        Alog::log("Created metadata file")
        tfile = "/tmp/amun-client/" + ident
        open(tfile,"w") { |f|
          f.write(CGI.unescapeHTML(resp.body).gsub!("\015",""))
        }
        Alog::log("Created task file")
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

