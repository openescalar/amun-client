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

Name:		amun-client	
Version:	0.1
Release:	0%{?dist}
Summary:	Amun Client allows scaling, script execution and monitoring of cloud instances.

Group:		Administration
License:	Apache License 2.0
URL:		http://www.openescalar.org
Source0:	amun-client-0.1.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Requires:	ruby >= 1.9, ruby-libs >= 1.9, rubygems, rubygem-stomp, collectd >= 4

%description
Amun Client is part of Amun's Cloud Management framework from OpenEscalar. This client allows instances to request tasks, execute scripts, send server stats and auto scale.

%prep
%setup -q


%build
make %{?_smp_mflags}


%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%post
ln -s /opt/openescalar/amun-client/bin/amun-client /etc/init.d/amun-client
/sbin/chkconfig amun-client on

%preun
/sbin/chkconfig amun-client off
rm -f /etc/init.d/amun-client

%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
/opt/openescalar/amun-client/*
/etc/collectd.conf
%doc



%changelog
* Sat Nov 4 2012 Miguel Z - openescalar (at) gmail.com
- Created 

