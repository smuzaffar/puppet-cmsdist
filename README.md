A `cmsdist` provider for the package resource which allows you to install CMSSW
and related packages using apt-get.

## The cmsdist provider.

The `cmsdist` provider extends the standard puppet `package` resource.

#### Installing CMSSW, puppet way:

A simple example is:

    package {"cms+cmssw+CMSSW_7_1_0":
      ensure => present,
      provider => cmsdist,
    }

this will setup a CMSSW installation area in `/opt/cms` using the default
architecture `slc6_amd64_gcc481`, owned by root and install
`cms+cmssw+CMSSW_7_1_0` there. Packages will be downloaded from the standard CMS
repository, `https://cmsrep.cern.ch/cmssw/cms`.

#### Customising installation

Notice that the installation prefix, the architecture and the installation user
can be configured using the the `install_options` property of the package
resource. The above is equivalent to:

    package {"cms+cmssw+CMSSW_7_1_0":
      ensure => present,
      provider => cmsdist,
      install_options => [{
        "install_prefix" => "/opt/cms",
        "install_user" => "cmsbuild",
        "architecture" => "slc6_amd64_gcc481",
        "server" => "cmsrep.cern.ch",
        "server_path" => "cmssw/cms",
      }]
    }

#### Installing multiple packages

Multiple packages can be installed as usual either by repeating the resource
declaration or passing a list as name. E.g.:

    package {["cms+cmssw+CMSSW_7_1_0", "cms+cmssw+CMSSW_6_2_0"]:
      ensure => present,
      provider => cmsdist,
    }

will happily install both `cms+cmssw+CMSSW_7_1_0` and `cms+cmssw+CMSSW_6_2_0`.

#### Installing multiple architectures

In case you want to install a given package for more than one architecture, you
can append the architecture to the package name like the following:

    package {["cms+cmssw+CMSSW_7_1_0/slc6_amd64_gcc490",
              "cms+cmssw+CMSSW_7_1_0/slc6_amd64_gcc481"]:
      ensure => present,
      provider => cmsdist,
    }

notice that in this case the architecture specified in `install_options` will
simply be ignored.
