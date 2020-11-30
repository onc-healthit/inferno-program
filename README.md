<img
src="https://raw.githubusercontent.com/onc-healthit/inferno/master/public/images/inferno_logo.png"
width="300px" />

[![Build
Status](https://travis-ci.org/onc-healthit/inferno-program.svg?branch=master)](https://travis-ci.org/onc-healthit/inferno-program)

# Inferno Program Edition

## ONC 21st Century Cures Open API Certification Testing

**Inferno Program Edition** is a streamlined testing tool for Health Level 7 (HL7®)
Fast Healthcare Interoperability Resources (FHIR®) services seeking to meet the
requirements of the Standardized API for Patient and Population Services
criterion § 170.315(g)(10) in the 2015 Edition Cures Update.

**Inferno Program Edition** behaves like an API consumer, making a series of
HTTP requests that mimic a real world client to ensure that the API supports all
required
standards, including:
* FHIR Release 4.0.1
* FHIR US Core Implementation Guide (IG) STU 3.1.1
* SMART Application Launch Framework Implementation Guide Release 1.0.0
* HL7 FHIR Bulk Data Access (Flat FHIR) (v1.0.0: STU 1)

**Inferno Program Edition** is open source and freely available for use or
adoption by the health IT community including EHR vendors, health app
developers, and testing labs. It can be used as a testing tool for the EHR
Certification program supported by the Office of the National Coordinator for
Health IT (ONC).

**Inferno Program Edition** is a pre-configured and customized version of the
open source [Inferno](https://github.com/onc-healthit/inferno) FHIR
testing tool, and only contains tests and functionality relevant to the ONC
Certification Program.  Users interested in extending or reusing this open
testing capability to meet their own needs are encouraged to visit the [Inferno
GitHub repository](https://github.com/onc-healthit/inferno).

## Installation and Deployment

### Docker Installation

Docker is the recommended installation method for Windows devices and can also
be used on Linux and MacOS hosts.

1. Install [Docker](https://www.docker.com/) for the host platform as well as
   the [docker-compose](https://docs.docker.com/compose/install/) tool (which
   may be included in the distribution, as is the case for Windows and MacOS).
2. Download the [latest release of the `inferno`
   project](https://github.com/onc-healthit/inferno-program/releases) to your local
   computer in a directory of your choice.
3. Open a terminal in the directory where the project was downloaded (above).
4. Run the command `docker-compose up --build` to start the server. This will
   automatically build the Docker image and launch Inferno, the HL7 FHIR Validator,
   and an NGINX web server.
5. Navigate to http://localhost:4567 to find the running application.

If the docker image gets out of sync with the underlying system, such as when
new dependencies are added to the application, you need to run `docker-compose
up --build` to rebuild the containers.

Check out the [Troubleshooting
Documentation](https://github.com/onc-healthit/inferno/wiki/Troubleshooting) for
help.

<!--### Native Installation

Inferno can installed and run locally on your machine.  Install the following
dependencies first:

* [Ruby 2.5+](https://www.ruby-lang.org/en/)
* [Ruby Bundler](http://bundler.io/)
* [SQLite](https://www.sqlite.org/)

And run the following commands from the terminal:

```sh
# MacOS or Linux
git clone https://github.com/onc-healthit/inferno-program
cd inferno
bundle install
bundle exec rackup
```

Inferno can then be accessed at http://localhost:4567 in a web browser.

If you would like to use a different port it can be specified when calling
`rackup`.  For example, the following command would host Inferno on port 3000:

```sh
bundle exec rackup -p 3000
```
-->

### Terminology Support

#### 2020-November-30 UMLS Auth Workaround

IMPORTANT: As of November 2020, UMLS login now requires the use of a federated login provider, such as Google, Microsoft, or https://login.gov. This change breaks the first step of the terminology build process outlined below.

As a temporary workaround, if you download https://download.nlm.nih.gov/umls/kss/2019AB/umls-2019AB-full.zip (note: this file is several GB in size), rename it `umls.zip` and place it in `<inferno root>/tmp/terminology`, that should allow the terminology processing to skip the download step and continue normally. This also eliminates the need to create the `.env` file (outlined below).

We hope to have this login system supported in the near future, which will re-enable the ability to do a completely automated terminology build from start to finish.

For more information on the UTS sign-in process changes, visit https://www.nlm.nih.gov/research/umls/uts-changes.html.

#### Terminology prerequisites

In order to validate terminologies, Inferno must be loaded with files generated
from the Unified Medical Language System (UMLS).  The UMLS is distributed by the
National Library of Medicine (NLM) and requires an account to access.

Inferno provides some rake tasks which may make this process easier, as well as
a Dockerfile and docker-compose file that will create the validators in a
self-contained environment.

Prerequisites:

* A UMLS account
* A working Docker toolchain, which has been assigned at least 10GB of RAM (The Metathesaurus step requires 8GB of RAM for the Java process)
  * Note: the Docker terminology process will not run unless Docker has access to at least 10GB of RAM.
* At least 33 GB of free disk space on the Host OS, for downloading/unzipping/processing the terminology files.
  * Note: this space needs to be allocated on the host because Docker maps these files through to the Host, to allow for building in the dedicated terminology container.
* A copy of the Inferno repository, which contains the required Docker and Ruby files

You can prebuild the terminology docker container by running the following command:

```sh
docker-compose -f terminology_compose.yml build
```

Once the container is built, you will have to add your UMLS username and passwords to a file named `.env` at the root of the inferno project. The file should look like this (replacing `your_username` and `your_password` with your UMLS username/password, respectively):

```sh
UMLS_USERNAME=your_username
UMLS_PASSWORD=your_password
```

Note that _anything_ after the equals sign in `.env` will be considered part of the variable, so don't wrap your username/password in quotation marks (unless they're actually part of your username).

Once that file exists, you can run the terminology creation task by using the following commands, in order:

```sh
docker-compose -f terminology_compose.yml up
```

This will run the terminology creation steps in order, using the UMLS credentials supplied in `.env`. These tasks may take several hours. If the creation task is cancelled in progress and restarted, it will restart after the last _completed_ step. Intermediate files are saved to `tmp/terminology` in the Inferno repository that the Docker Compose job is run from, and the validators are saved to `resources/terminology/validators/bloom`, where Inferno can use them for validation.

#### Cleanup

Once the terminology building is done, the `.env` file should be deleted to remove the UMLS username and password from the system.

Optionally, the files and folders in `tmp/terminology/` can be deleted after terminology building to free up space, as they are several GB in size. If you intend to re-run the terminology builder, these files can be left to speed up building in the future, since the builder will be able to skip the initial download/preprocessing steps.

#### Spot Checking the Terminology Files

You can use the following `rake` command to spot check the validators to make sure they are installed correctly:

```ruby
bundle exec rake "terminology:check_code[91935009,http://snomed.info/sct, http://hl7.org/fhir/us/core/ValueSet/us-core-allergy-substance]"
```

Should return:

```shell
X http://snomed.info/sct|91935009  is not in http://hl7.org/fhir/us/core/ValueSet/us-core-allergy-substance
```

And

```ruby
bundle exec rake "terminology:check_code[91935009,http://snomed.info/sct]"
```

Should return:

```shell
✓ http://snomed.info/sct|91935009  is in http://snomed.info/sct
```

#### Manual build instructions

If this Docker-based method does not work based on your architecture, manual setup and creation of the terminology validators is documented [on this wiki page](https://github.com/onc-healthit/inferno/wiki/Installing-Terminology-Validators#building-the-validators-without-docker)

#### UMLS Data Sources

Some material in the UMLS Metathesaurus is from copyrighted sources of the respective copyright holders.
Users of the UMLS Metathesaurus are solely responsible for compliance with any copyright, patent or trademark
restrictions and are referred to the copyright, patent or trademark notices appearing in the original sources,
all of which are hereby incorporated by reference.

      Bodenreider O. The Unified Medical Language System (UMLS): integrating biomedical terminology.
      Nucleic Acids Res. 2004 Jan 1;32(Database issue):D267-70. doi: 10.1093/nar/gkh061.
      PubMed PMID: 14681409; PubMed Central PMCID: PMC308795.

### Reference Implementation

While it is recommended that users install Inferno locally, a reference
implementation of Inferno is hosted at https://inferno.healthit.gov/inferno

Users that would like to try out Inferno before installing locally can use that
reference implementation, but should be forewarned that the database will be
periodically refreshed and there is no guarantee that previous test runs will be
available in perpetuity.

## Supported Browsers

Inferno has been tested on the latest versions of Chrome, Firefox, Safari, and
Edge.  Internet Explorer is not supported at this time.

## Unit Tests

Inferno contains a robust set of self-tests to ensure that the test clients
conform to the specification and performs as intended.  To run these tests,
execute the following command:

```sh
bundle exec rake test
```

## Inspecting and Exporting Tests

Tests are written to be easily understood, even by those who aren't familiar
with Ruby.  They can be viewed directly [in this
repository](https://github.com/onc-healthit/inferno-program/tree/master/lib/modules).

Tests contain metadata that provide additional details and traceability to
standards.  The active tests and related metadata can be exported into CSV
format and saved to a file named `testlist.csv` with the following command:

```sh
bundle exec rake inferno:tests_to_csv
```

Arguments can be provided to the task in order to export a specific set of tests
or to specify the output file.

```sh
bundle exec rake inferno:tests_to_csv[onc_program,all_tests.csv]
```

To just choose the module and use the default groups and filename:

```sh
bundle exec rake inferno:tests_to_csv[onc_program]

```

## Running Tests from the Command Line
Inferno provides two methods of running tests via the command line: by directly
providing the sequences or running automated scripts

_Note: This feature is still in development and we are looking for feedback on
features and improvements in ways it can be used_

### Running Tests Directly

Testing sequences can be run from the command line via a rake task which takes
the sequence (or sequences) to be run and server url as arguments:
```sh
bundle exec rake inferno:execute[https://my-server.org/data,onc_program,ArgonautConformance]
```

### Running Automated Command Line Interface Scripts
For more complicated testing where passing arguments is unwieldy, Inferno
provides the ability to use a script containing parameters to drive test
execution. The provided `script_example.json` shows an example of this script
and how it can be used.  The `execute_batch` task runs the script:

```sh
bundle exec rake inferno:execute_batch[script.json]
```

Inferno also provides a  `generate_script` rake task which prompts the user for
a series of inputs which are then used to generate a script. The user is
expected to provide a url for the FHIR Server to be tested and the module name
from which sequences will be pulled.
```sh
bundle exec rake inferno:generate_script[https://my-server.org/data,onc]
```

## Using with Continuous Integration Systems
Instructions and examples are available in the [Continuous Integration Section
of the
Wiki](https://github.com/onc-healthit/inferno/wiki/Using-with-Continuous-Integration-Systems).

## Contact Us
The Inferno development team can be reached by email at
inferno@groups.mitre.org.  Inferno also has a dedicated [HL7 FHIR chat
channel](https://chat.fhir.org/#narrow/stream/153-inferno).

## License

Copyright 2020 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
