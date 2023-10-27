# OpenInSAR

OpenInSAR is a system for SAR and InSAR time series analysis.
This software will undergo extensive refactoring and development over the course of a 2 year project.

This current version was developed through a PhD project at Imperial College London. The accompanying thesis will be available [here when finalised](https://spiral.imperial.ac.uk/simple-search?location=%2F&query=Transient+Scattering&rpp=1&sort_by=score&order=desc&filter_field_1=author&filter_type_1=equals&filter_value_1=Agar).

**main** branch status:
[![](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/ubuntu-test-on-pull.yml/badge.svg)](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/)
[![](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/windows-test-on-pull.yml/badge.svg)](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/)

**dev** branch status:
[![](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/ubuntu-test-on-pull.yml/badge.svg?branch=dev)](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/)
[![](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/windows-test-on-pull.yml/badge.svg?branch=dev)](https://github.com/OpenInSAR-ICL/OpenInSAR/actions/workflows/)


## Get started

To get started, please refer to the documentation [here](/output/doc/index.html). The rest of this README describes the repository structure.

## Repository structure
``` Bash
git clone https://github.com/insar-uk/OpenInSAR
cd OpenInSAR
```

The repository contains the following directories:
- [Documentation](#doc)
- [Output files](#output)
- [Resources](#res)
- [Scripts](#scripts)
- [Source code](#src)
- [Tests](#test)

### Documentation {#doc}
``` Bash
cd /doc/
```

OpenInSAR uses Sphinx to generate documentation. The /doc/ folder contains the files used by Sphinx to generate the docs.

A guide to using Sphinx can be found [here](https://www.sphinx-doc.org/en/master/usage/quickstart.html).

### Output files
``` Bash
cd /output/
```

The output directory contains the finished product. This includes the web app and its documentation.

### Resources
``` Bash
cd /res/
```
The resources directory contains relatively small (under 32 MB) data files used in processing, such as geoid models.

### Scripts
``` Bash
cd /scripts/
```

The scripts directory contains any scripts that are useful for maintaining the repository, or testing. Such as scripts for building the documentation and web app.

### Source code
``` Bash
cd /src/
```

The source code directory contains the source code for the web app, the various services, and the data processing scripts.

### Tests
``` Bash
cd /test/
```

OpenInSAR uses pytest as an overarching testing framework. The /test/ directory contains the tests for the web app, the various services, and the data processing scripts.
