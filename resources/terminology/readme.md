## Optional Terminology Support

In order to validate terminologies Inferno can be loaded with files generated from the 
Unified Medical Language System (UMLS).  The UMLS is distributed by the National Library of Medicine (NLM)
and requires an account to access.

Inferno provides some rake tasks to make this process easier.
Inferno provides some rake tasks which may make this process easier, as well as a Dockerfile and docker-compose file that will create the validators in a self-contained environment.

## UMLS Data Sources
Some material in the UMLS Metathesaurus is from copyrighted sources of the respective copyright holders.
Users of the UMLS Metathesaurus are solely responsible for compliance with any copyright, patent or trademark
restrictions and are referred to the copyright, patent or trademark notices appearing in the original sources,
all of which are hereby incorporated by reference.

      Bodenreider O. The Unified Medical Language System (UMLS): integrating biomedical terminology.
      Nucleic Acids Res. 2004 Jan 1;32(Database issue):D267-70. doi: 10.1093/nar/gkh061.
      PubMed PMID: 14681409; PubMed Central PMCID: PMC308795.

## Building the validators with Docker

### Prerequisites
* A UMLS account
* A working Docker toolchain, which has been assigned at least 10GB of RAM (The Metathesaurus step requires 8GB of RAM for the Java process)
* A copy of the Inferno repository, which contains the required Docker and Ruby files

### Building and Running the Terminology Docker container
* You can prebuild the terminology docker container by running the following command:
```sh
docker-compose -f terminology_compose.yml build
```
* Once the container is built, you can run the terminology creation task by using the following commands, in order:
```sh
export UMLS_USERNAME=<your UMLS username>
export UMLS_PASSWORD=<your UMLS password>
docker-compose -f terminology_compose.yml up
```
This will run the terminology creation steps in order, using the UMLS credentials supplied. These tasks may take several hours. If the creation task is cancelled in progress and restarted, it will restart after the last _completed_ step. Intermediate files are saved to `tmp/terminology` in the Inferno repository that the Docker Compose job is run from, and the validators are saved to `resources/terminology/validators/bloom`, where Inferno can use them for validation.

## Building the validators without Docker
To build the validators without using the provided Docker script, run the following commands, from the Inferno repository root directory: 
```sh
export UMLS_USERNAME=<your UMLS username>
export UMLS_PASSWORD=<your UMLS password>
./bin/run_terminology.sh
```
This will run through all of the steps to create the validators on the local system, rather than in a Docker container. This step requires that Ruby be installed on your local system, and that you have run the `bundle install` task in your Inferno root directory as well.

## Manually creating the validators
If you want to manually walk through each step in the validator creation process, detailed instructions for each step are provided below:

### Download FHIR ValueSet and CodeSystem resources

Download the FHIR ValueSet and CodeSystem definitions:

```sh
bundle exec rake terminology:download_program_terminology
```

### Downloading the UMLS

Inferno provides a task which attempts to download the UMLS for you:

```sh
bundle exec rake terminology:download_umls[username, password]
```

*Note: username and passwords should be entered as strings to avoid issues with special characters.  For example*
```sh
bundle exec rake terminology:download_umls['jsmith','hunter2!']
```

Or
```sh
bundle exec rake 'terminology:download_umls[jsmith,hunter2!]'
```


This command requires a valid UMLS `username` and `password`.  Inferno does not store this information and 
only uses it to download the necessary files during this step.

If this command fails, or you do not have a UMLS account, the file can be
downloaded directly from the UMLS website.

https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.htm

### Unzipping the UMLS files
The UMLS files should be decompressed for processing and use.  The metamorphoSys utility provided
within the UMLS distribution must be unzipped as well.

Inferno provides a task which will attempt to unzip the files into the correct location
for further operation:

```sh
bundle exec rake terminology:unzip_umls
```

Users can also manually unzip the files.  The mmsys.zip file should be unzipped to the same
directory as the other downloaded files.

See https://www.nlm.nih.gov/research/umls/implementation_resources/metamorphosys/help.html#screens_tabs
for more details.

### Creating a UMLS Subset

The metamorphoSys tool can customize and install UMLS sources.  Inferno provides
a configuration file and a task to help run the metamorphoSys tool.

```sh
bundle exec rake terminology:run_umls
```

The UMLS tool can also be manually executed.

*Note: This step can take a while to finish*

### Loading the subset

Inferno loads the UMLS subset into a SQLite database for executing the queries which support creating the terminology validators.
A shell script is provided at the root of the project to automatically create the database

```sh
./create_umls.sh
```

### Creating the Terminology Validators

Once the UMLS database has been created the terminology validators can be created for Inferno's use.

```sh
bundle exec rake terminology:create_vs_validators
```

### Cleaning up
The UMLS distribution is large and no longer required by Inferno after processing.

Inferno provides a utility which removes the umls.zip file, the unzipped distribution, and the
installed subset

```sh
bundle exec rake terminology:cleanup_umls
```
