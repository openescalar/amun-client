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

OPENESCALAR = $(DESTDIR)/opt/openescalar
AMUNC = $(OPENESCALAR)/amun-client
AMUNCLIB = $(AMUNC)/lib
AMUNCBIN = $(AMUNC)/bin
AMUNCCONF = $(AMUNC)/conf
COLLECTCONF = $(DESTDIR)/etc

all :

.PHONY : install
install :
	install -d $(OPENESCALAR)
	install -d $(AMUNC)
	install -d $(AMUNCLIB) $(AMUNCBIN) $(AMUNCCONF) $(COLLECTCONF)
	install -C bin/amun-client $(AMUNCBIN)
	install -C lib/oeclient.rb $(AMUNCLIB)
	ln -s $(AMUNCBIN)/amun-client /etc/init.d/amun-client

.PHONY : uninstall
uninstall :
	rm -rf $(AMUNC)
