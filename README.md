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

Inferno Program Edition is designed to be run using
[Docker](https://www.docker.com/) to ensure consistency of execution across a
wide range of host environments, including Windows, Linux and MacOS.

1. Install [Docker](https://www.docker.com/) for the host platform as well as
   the [docker-compose](https://docs.docker.com/compose/install/) tool, if
   necessary. Docker-compose may be included in the Docker distribution, as is
   the case for Windows and MacOS.
2. Download the [latest release of the Inferno Program Edition
   project](https://github.com/onc-healthit/inferno-program/releases) to your local
   computer in a directory of your choice.
3. Open a terminal in the directory where the project was downloaded (above).
4. Run the command `docker-compose up --build` to start the server. This will
   automatically build the Docker image and launch Inferno, the HL7 FHIR Validator,
   and an NGINX web server, suitable for use in a single user environment.
   For information about running Inferno in a multi-user server environment,
   please refer to the [Deploying Inferno in a Server
   Environment](#deploying-inferno-in-a-server-environment) section below.
5. Navigate to http://localhost:4567 to find the running application.

If the docker image gets out of sync with the underlying system, such as when
new dependencies are added to the application, you need to run `docker-compose
up --build` to rebuild the containers.

Check out the [Troubleshooting
Documentation](https://github.com/onc-healthit/inferno/wiki/Troubleshooting) for
help.

### Terminology Support
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
* At least 90 GB of free disk space on the Host OS, for downloading/unzipping/processing the terminology files.
  * Note: this space needs to be allocated on the host because Docker maps these files through to the Host, to allow for building in the dedicated terminology container.
  * Note: see the `.env` file section below for a way to reduce this space requirement to around 40 GB.
* A copy of the Inferno repository, which contains the required Docker and Ruby files

You can prebuild the terminology docker container by running the following command:

```sh
docker-compose -f terminology_compose.yml build
```

Once the container is built, you will have to add your UMLS API key to a file named `.env` at the root of the inferno project. This API key is used to authenticate the user to download the UMLS zip files. To find your UMLS API key, sign into [the UTS homepage](https://uts.nlm.nih.gov/uts/), click on `My Profile` in the top right, and copy the `API KEY` value from the `UMLS Licensee Profile`. 

The `.env` file should look like this (replacing `your_api_key`  with your UMLS API key):

```sh
UMLS_API_KEY=your_api_key
# optional
CLEANUP=true
```

Note that _anything_ after the equals sign in `.env` will be considered part of the variable, so don't wrap your API key in quotation marks.

Optionally: you can add a second environment variable, named `CLEANUP` and set to `true`, to that same file. This tells the build system to delete the "build files"--everything except for the finished databases--between each version build. This caps the space requirement at ~40 GB, rather than 90 GB.

We've included a template `.env` file in `.env.example`, with these values commented out. To create your `.env` file, you can copy the contents of that file into `.env`, and update the contents with your API key/uncomment the `CLEANUP` as desired.

Once that file exists, you can run the terminology creation task by using the following command:

```sh
docker-compose -f terminology_compose.yml up
```

This will run the terminology creation steps in order. These tasks may take several hours. If the creation task is cancelled in progress and restarted, it will restart after the last _completed_ step. Intermediate files are saved to `tmp/terminology` in the Inferno repository that the Docker Compose job is run from, and the validators are saved to `resources/terminology/validators/bloom`, where Inferno can use them for validation.

#### Cleanup

Once the terminology building is done, the `.env` file should be deleted to remove your UMLS API key from the system.

Optionally, the files and folders in `tmp/terminology/` can be deleted after terminology building to free up space, as they are several GB in size. If you intend to re-run the terminology builder, these files can be left to speed up building in the future, since the builder will be able to skip the initial download/preprocessing steps.

#### Verifying a Successful Terminology Build

The following rake task will check that the built terminology contains the expected number of codes for each system:

```ruby
bundle exec rake terminology:check_built_terminology
```

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

## Validator Service

Inferno Program Edition uses an [external validator
service](https://github.com/inferno-community/fhir-validator-wrapper/) that
is run in a separate process to validate FHIR resources received from the
system under test. When running Inferno in Docker using the
`docker-compose.yml` file from this repository, the validator service is run
as a separate Docker container and is available to Inferno via a RESTful API.
If Inferno is not run using Docker and the `docker-compose.yml` file, then
the validator service must be run separately and Inferno's `config.yml` must
be updated to point to this service.

### Updating the Validator Service in Docker

When Inferno is updated to a new version, it will occasionally require a new
version of the validator service. If Inferno is being run using the
`docker-compose.yml` file in this repository, the new validator version will
be specified as part of the `validator_service` image declaration following
an update through Git.

To download the Docker files associated with the new version, run
`docker-compose pull` in the Inferno directory. Once the new files are
downloaded, you can update the version by running `docker-compose down`,
followed by `docker-compose up --force-recreate`. This will restart Inferno
and the validator service with the new service version.

### Updating the Validator Service outside of Docker

If Inferno isn't running in Docker, the validator service will have to be
updated manually. See the [FHIR Validator Wrapper
repository](https://github.com/inferno-community/fhir-validator-wrapper) for
more information on how to run the validator service outside of docker.

## Deploying Inferno in a Server Environment

Inferno's default configuration is designed to be lightweight and
run on the users host machine.  If you would like to run a shared instance
of Inferno, you can use the docker-compose configuration provided in
`docker-compose.postgres.yml`, which attaches Inferno to a Postgres
database to provide more stability when multiple tests are run
simultaniously.  This requires higher resource utilization on the host
machine than the default configuration, which uses SQLite for
storage.

To run this configuration, you use `docker-compose.postgres.yml`
file:
```sh
docker-compose -f docker-compose.postgres.yml up --build -d
```

To stop the service and destroy the containers, run:
```sh
docker-compose -f docker-compose.postgres.yml down
```

This configuration will persist data if the container is stopped
or destroyed.  If you would like to clear the data in the database,
and have it recreated from scratch the next time the application is started,
you can run the following commands:

```sh
docker-compose -f docker-compose.postgres.yml down
docker volume ls | grep inferno-pgdata # Lists active volumes
docker volume rm inferno-program_inferno-pgdata # Volume name will end in inferno-pgdata
```

For another example of deploying Inferno in a production environment, review
[the docker-compose file](https://github.com/onc-healthit/inferno.healthit.gov/blob/master/docker-compose.yml)
used to deploy Inferno Program Edition, Inferno Community Edition, and a
number of services on https://inferno.healthit.gov/inferno.

## Reference Implementation

While it is recommended that users install Inferno locally, a reference
implementation of Inferno is hosted at https://inferno.healthit.gov/inferno

Users that would like to try out Inferno before installing locally can use that
reference implementation, but should be forewarned that the database will be
periodically refreshed and there is no guarantee that previous test runs will be
available in perpetuity.

To see an example of using the reference implementation, see the [walkthrough](https://github.com/onc-healthit/inferno-program/wiki/Walkthrough) on the wiki.

## Supported Browsers

Inferno has been tested on the latest versions of Chrome, Firefox, Safari, and
Edge. Internet Explorer is not supported at this time.

## Unit Tests

Inferno contains a robust set of self-tests to ensure that the test clients
conform to the specification and performs as intended.  To run these tests,
execute the following command:

```sh
bin/run_tests.sh
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
providing the sequences or running automated scripts.  You can either run these commands
within docker containers through `docker-compose`, or directly in your own environment
using ruby natively.  We recommend using the `docker-compose` approach because it
ensures that the appropriate validation services are in place.

_Note: This feature is still in development and we are looking for feedback on
features and improvements in ways it can be used_

### Running Tests Directly

Testing sequences can be run from the command line via a rake task which takes
the sequence (or sequences) to be run and server url as arguments:
```sh
docker-compose run inferno bundle exec rake db:create db:migrate inferno:execute[https://inferno.healthit.gov/reference-server/r4,onc_program,UsCoreR4CapabilityStatement,USCore311Patient]
```

### Running Automated Command Line Interface Scripts
For more complicated testing where passing arguments is unwieldy, Inferno
provides the ability to use a script containing parameters to drive test
execution. The provided `./batch/inferno.healthit.gov.json` shows an example of this script
and how it can be used.  The `execute_batch` task runs the script:

```sh
docker-compose run inferno bundle exec rake db:create db:migrate inferno:execute_batch[./batch/inferno.healthit.gov.json]
```

Inferno also provides a  `generate_script` rake task which prompts the user for
a series of inputs which are then used to generate a script. The user is
expected to provide a url for the FHIR Server to be tested and the module name
from which sequences will be pulled.
```sh
bundle exec rake db:create db:migrate inferno:generate_script[https://my-server.org/data,onc_program]
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

Copyright 2021 The MITRE Corporation

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
