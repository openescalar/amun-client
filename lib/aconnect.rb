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

module Aconnect
  def self.queryUrl(args) 
    case args[:action]
       when :task
          path = "/task?#{args[:query]}"
       when :ping
          path = "/ping?#{args[:query]}"
       when :olb
          path = "/olb?#{args[:query]}"
       when :ovpn
          path = "/ovpn?#{args[:query]}"
       when :odns
          path = "/odns?#{args[:query]}"
       when :metadata
          path = "/metadata?#{args[:query]}"
       when :event
          path = "/event?#{args[:query]}"
       when :escalar
          path = "/escalar?#{args[:query]}"
       else 
          path = args[:query]
    end
    args[:host] ? host = args[:host] : host = Aconfig::config["oeapiserver"]
    args[:port] ? port = args[:port] : host = Aconfig::config["oeapiport"]
    begin
      sock = Net::HTTP.new(host,port)
      resp = sock.get(path)
      resp.body
    rescue
      Alog::log("Error while connecting to Api server")
    end
  end
end

