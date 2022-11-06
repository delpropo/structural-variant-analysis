# Snakemake workflow: `<name>`

[![Snakemake](https://img.shields.io/badge/snakemake-≥6.3.0-brightgreen.svg)](https://snakemake.github.io)
[![GitHub actions status](https://github.com/<owner>/<repo>/workflows/Tests/badge.svg?branch=main)](https://github.com/<owner>/<repo>/actions?query=branch%3Amain+workflow%3ATests)


A Snakemake workflow for analysis of structural variants using

[[_TOC_

## Usage

The usage of this workflow is described in the [Snakemake Workflow Catalog](https://snakemake.github.io/snakemake-workflow-catalog/?usage=<owner>%2F<repo>).

If you use this workflow in a paper, don't forget to give credits to the authors by citing the URL of this (original) <repo>sitory and its DOI (see above).
  
## Data sets

 Previously analyzed bam files will be collected
  
  | file | reference| id | 
  |------|----------|----|
  |file_1|genome    |EP# |
  |file_2|genome    |EP# |

## data extraction
  
  Determine if any data was extracted
  
## requirements
  
  ### available from bioconda
  snakedeploy
  smoove
  expansionhunter
  
  ### separate download
  melt: mobile element locator tool
  ```
  https://melt.igs.umaryland.edu/index.php
  requires bowtie2
  ```
  
##
  java –jar MELT.jar Runtime --help/-help/-h
  
## deployment on Armis2
  
  melt is available on Armis2 modules.  Smoove and ExpansionHunter are not and will need to be loaded in conda.
  
  Snakedeploy can be setup to use melt automatically on Armis2
  ```
  module load Bioinformatics
  module load melt
  ``
  
source /home/delpropo/miniconda3/etc/profile.d/conda.sh
conda activate snakemake

# TODO

* Replace `<owner>` and `<repo>` everywhere in the template (also under .github/workflows) with the correct `<repo>` name and owning user or organization.
* Replace `<name>` with the workflow name (can be the same as `<repo>`).
* Replace `<description>` with a description of what the workflow does.
* The workflow will occur in the snakemake-workflow-catalog once it has been made public. Then the link under "Usage" will point to the usage instructions if `<owner>` and `<repo>` were correctly set.
  
  
