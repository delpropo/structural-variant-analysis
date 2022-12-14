if "restrict-regions" in config["processing"]:

    rule compose_regions:
        input:
            config["processing"]["restrict-regions"],
        output:
            "results/called/{contig}.regions.bed",
        conda:
            "../envs/bedops.yaml"
        shell:
            "bedextract {wildcards.contig} {input} > {output}"


rule call_variants:
    input:
        bam=get_sample_bams,
        ref="resources/genome.fasta",
        idx="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        tbi="resources/variation.noiupac.vcf.gz.tbi",
        regions=(
            "results/called/{contig}.regions.bed"
            if config["processing"].get("restrict-regions")
            else []
        ),
    output:
        gvcf=protected("results/called/{sample}.{contig}.g.vcf.gz"),
    log:
        "logs/gatk/haplotypecaller/{sample}.{contig}.log",
    params:
        extra=get_call_variants_params,
    wrapper:
        "0.59.0/bio/gatk/haplotypecaller"


rule combine_calls:
    input:
        ref="resources/genome.fasta",
        gvcfs=expand(
            "results/called/{sample}.{{contig}}.g.vcf.gz", sample=samples.index
        ),
    output:
        gvcf="results/called/all.{contig}.g.vcf.gz",
    log:
        "logs/gatk/combinegvcfs.{contig}.log",
    wrapper:
        "0.74.0/bio/gatk/combinegvcfs"


rule genotype_variants:
    input:
        ref="resources/genome.fasta",
        gvcf="results/called/all.{contig}.g.vcf.gz",
    output:
        vcf=temp("results/genotyped/all.{contig}.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["GenotypeGVCFs"],
    log:
        "logs/gatk/genotypegvcfs.{contig}.log",
    wrapper:
        "0.74.0/bio/gatk/genotypegvcfs"


rule merge_variants:
    input:
        vcfs=lambda w: expand(
            "results/genotyped/all.{contig}.vcf.gz", contig=get_contigs()
        ),
    output:
        vcf="results/genotyped/all.vcf.gz",
    log:
        "logs/picard/merge-genotyped.log",
    wrapper:
        "0.74.0/bio/picard/mergevcfs"
rule annotate_variants:
    input:
        calls="results/filtered/all.vcf.gz",
        cache="resources/vep/cache",
        plugins="resources/vep/plugins",
    output:
        calls=report(
            "results/annotated/all.vcf.gz",
            caption="../report/vcf.rst",
            category="Calls",
        ),
        stats=report(
            "results/stats/all.stats.html",
            caption="../report/stats.rst",
            category="Calls",
        ),
    params:
        # Pass a list of plugins to use, see https://www.ensembl.org/info/docs/tools/vep/script/vep_plugins.html
        # Plugin args can be added as well, e.g. via an entry "MyPlugin,1,FOO", see docs.
        plugins=config["params"]["vep"]["plugins"],
        extra=config["params"]["vep"]["extra"],
    log:
        "logs/vep/annotate.log",
    threads: 4
    wrapper:
        "0.74.0/bio/vep/annotate"
if "restrict-regions" in config["processing"]:

    rule compose_regions:
        input:
            config["processing"]["restrict-regions"],
        output:
            "results/called/{contig}.regions.bed",
        conda:
            "../envs/bedops.yaml"
        shell:
            "bedextract {wildcards.contig} {input} > {output}"


rule call_variants:
    input:
        bam=get_sample_bams,
        ref="resources/genome.fasta",
        idx="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        tbi="resources/variation.noiupac.vcf.gz.tbi",
        regions=(
            "results/called/{contig}.regions.bed"
            if config["processing"].get("restrict-regions")
            else []
        ),
    output:
        gvcf=protected("results/called/{sample}.{contig}.g.vcf.gz"),
    log:
        "logs/gatk/haplotypecaller/{sample}.{contig}.log",
    params:
        extra=get_call_variants_params,
    wrapper:
        "0.59.0/bio/gatk/haplotypecaller"


rule combine_calls:
    input:
        ref="resources/genome.fasta",
        gvcfs=expand(
            "results/called/{sample}.{{contig}}.g.vcf.gz", sample=samples.index
        ),
    output:
        gvcf="results/called/all.{contig}.g.vcf.gz",
    log:
        "logs/gatk/combinegvcfs.{contig}.log",
    wrapper:
        "0.74.0/bio/gatk/combinegvcfs"


rule genotype_variants:
    input:
        ref="resources/genome.fasta",
        gvcf="results/called/all.{contig}.g.vcf.gz",
    output:
        vcf=temp("results/genotyped/all.{contig}.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["GenotypeGVCFs"],
    log:
        "logs/gatk/genotypegvcfs.{contig}.log",
    wrapper:
        "0.74.0/bio/gatk/genotypegvcfs"


rule merge_variants:
    input:
        vcfs=lambda w: expand(
            "results/genotyped/all.{contig}.vcf.gz", contig=get_contigs()
        ),
    output:
        vcf="results/genotyped/all.vcf.gz",
    log:
        "logs/picard/merge-genotyped.log",
    wrapper:
        "0.74.0/bio/picard/mergevcfs"
import pandas as pd
from snakemake.utils import validate
from snakemake.utils import min_version

min_version("5.18.0")


report: "../report/workflow.rst"


container: "continuumio/miniconda3:4.8.2"


###### Config file and sample sheets #####
configfile: "config/config.yaml"


validate(config, schema="../schemas/config.schema.yaml")

samples = pd.read_table(config["samples"]).set_index("sample", drop=False)
validate(samples, schema="../schemas/samples.schema.yaml")

units = pd.read_table(config["units"], dtype=str).set_index(
    ["sample", "unit"], drop=False
)
units.index = units.index.set_levels(
    [i.astype(str) for i in units.index.levels]
)  # enforce str in index
validate(units, schema="../schemas/units.schema.yaml")


##### Wildcard constraints #####
wildcard_constraints:
    vartype="snvs|indels",
    sample="|".join(samples.index),
    unit="|".join(units["unit"]),


##### Helper functions #####

# contigs in reference genome
def get_contigs():
    with checkpoints.genome_faidx.get().output[0].open() as fai:
        return pd.read_table(fai, header=None, usecols=[0], squeeze=True, dtype=str)


def get_fastq(wildcards):
    """Get fastq files of given sample-unit."""
    fastqs = units.loc[(wildcards.sample, wildcards.unit), ["fq1", "fq2"]].dropna()
    if len(fastqs) == 2:
        return {"r1": fastqs.fq1, "r2": fastqs.fq2}
    return {"r1": fastqs.fq1}


def is_single_end(sample, unit):
    """Return True if sample-unit is single end."""
    return pd.isnull(units.loc[(sample, unit), "fq2"])


def get_read_group(wildcards):
    """Denote sample name and platform in read group."""
    return r"-R '@RG\tID:{sample}\tSM:{sample}\tPL:{platform}'".format(
        sample=wildcards.sample,
        platform=units.loc[(wildcards.sample, wildcards.unit), "platform"],
    )


def get_trimmed_reads(wildcards):
    """Get trimmed reads of given sample-unit."""
    if not is_single_end(**wildcards):
        # paired-end sample
        return expand(
            "results/trimmed/{sample}-{unit}.{group}.fastq.gz",
            group=[1, 2],
            **wildcards
        )
    # single end sample
    return "results/trimmed/{sample}-{unit}.fastq.gz".format(**wildcards)


def get_sample_bams(wildcards):
    """Get all aligned reads of given sample."""
    return expand(
        "results/recal/{sample}-{unit}.bam",
        sample=wildcards.sample,
        unit=units.loc[wildcards.sample].unit,
    )


def get_regions_param(regions=config["processing"].get("restrict-regions"), default=""):
    if regions:
        params = "--intervals '{}' ".format(regions)
        padding = config["processing"].get("region-padding")
        if padding:
            params += "--interval-padding {}".format(padding)
        return params
    return default


def get_call_variants_params(wildcards, input):
    return (
        get_regions_param(
            regions=input.regions, default="--intervals {}".format(wildcards.contig)
        )
        + config["params"]["gatk"]["HaplotypeCaller"]
    )


def get_recal_input(bai=False):
    # case 1: no duplicate removal
    f = "results/mapped/{sample}-{unit}.sorted.bam"
    if config["processing"]["remove-duplicates"]:
        # case 2: remove duplicates
        f = "results/dedup/{sample}-{unit}.bam"
    if bai:
        if config["processing"].get("restrict-regions"):
            # case 3: need an index because random access is required
            f += ".bai"
            return f
        else:
            # case 4: no index needed
            return []
    else:
        return f


def get_snpeff_reference():
    return "{}.{}".format(config["ref"]["build"], config["ref"]["snpeff_release"])


def get_vartype_arg(wildcards):
    return "--select-type-to-include {}".format(
        "SNP" if wildcards.vartype == "snvs" else "INDEL"
    )


def get_filter(wildcards):
    return {"snv-hard-filter": config["filtering"]["hard"][wildcards.vartype]}



# snakemake -s delly_EP173.SMK -c1 --use-envmodules


# GRCh38_full_analysis_set_plus_decoy_hla.fa was used for alignment
genome = [
"/nfs/turbo/umms-mblabsens/EP173/From_UNT/bams_old/GRCh38_full_analysis_set_plus_decoy_hla.fa",
"/nfs/turbo/umms-mblabsens/EP173/From_UNT/bams_old/GRCh38_full_analysis_set_plus_decoy_hla.fa.fai",]


samples = ["173-4", "2622", "3646", "7347"]

# samples = ["173_4"] only for chr22

bcf_chr22_files = expand("delly/{sample}.chr22.delly.bcf", sample=samples)

bcf_files = expand("delly/{sample}.delly.bcf", sample=samples)

rule all:
    input:
        bcf_files
    run:
        print("run complete")




rule delly:
    input:
        "/nfs/turbo/umms-mblabsens/EP173/From_UNT/bams_old/{sample}.bam"
    output:
        "results/delly/{sample}.delly.bcf"
    envmodules:
        "Bioinformatics",
        "delly2"
    shell:
        'delly call -o {output} -g {genome[0]} {input} '



rule delly_bcf:
    input:
        ref="genome.fasta",
        alns=["mapped/a.bam"],
        # optional
        exclude="human.hg19.excl.tsv",
    output:
        "sv/calls.bcf",
    params:
        uncompressed_bcf=True,
        extra="",  # optional parameters for delly (except -g, -x)
    log:
        "logs/delly.log",
    threads: 2  # It is best to use as many threads as samples
    wrapper:
        "v1.18.3/bio/delly"


rule delly_vcfgz:
    input:
        ref="genome.fasta",
        alns=["mapped/a.bam"],
        # optional
        exclude="human.hg19.excl.tsv",
    output:
        "sv/calls.vcf.gz",
    params:
        extra="",  # optional parameters for delly (except -g, -x)
    log:
        "logs/delly.log",
    threads: 2  # It is best to use as many threads as samples
    wrapper:
        "v1.18.3/bio/delly"rule select_calls:
    input:
        ref="resources/genome.fasta",
        vcf="results/genotyped/all.vcf.gz",
    output:
        vcf=temp("results/filtered/all.{vartype}.vcf.gz"),
    params:
        extra=get_vartype_arg,
    log:
        "logs/gatk/selectvariants/{vartype}.log",
    wrapper:
        "0.59.0/bio/gatk/selectvariants"


rule hard_filter_calls:
    input:
        ref="resources/genome.fasta",
        vcf="results/filtered/all.{vartype}.vcf.gz",
    output:
        vcf=temp("results/filtered/all.{vartype}.hardfiltered.vcf.gz"),
    params:
        filters=get_filter,
    log:
        "logs/gatk/variantfiltration/{vartype}.log",
    wrapper:
        "0.74.0/bio/gatk/variantfiltration"


rule recalibrate_calls:
    input:
        vcf="results/filtered/all.{vartype}.vcf.gz",
    output:
        vcf=temp("results/filtered/all.{vartype}.recalibrated.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["VariantRecalibrator"],
    log:
        "logs/gatk/variantrecalibrator/{vartype}.log",
    wrapper:
        "0.74.0/bio/gatk/variantrecalibrator"


rule merge_calls:
    input:
        vcfs=expand(
            "results/filtered/all.{vartype}.{filtertype}.vcf.gz",
            vartype=["snvs", "indels"],
            filtertype="recalibrated"
            if config["filtering"]["vqsr"]
            else "hardfiltered",
        ),
    output:
        vcf="results/filtered/all.vcf.gz",
    log:
        "logs/picard/merge-filtered.log",
    wrapper:
        "0.74.0/bio/picard/mergevcfs"
rule trim_reads_se:
    input:
        unpack(get_fastq),
    output:
        temp("results/trimmed/{sample}-{unit}.fastq.gz"),
    params:
        **config["params"]["trimmomatic"]["se"],
        extra="",
    log:
        "logs/trimmomatic/{sample}-{unit}.log",
    wrapper:
        "0.74.0/bio/trimmomatic/se"


rule trim_reads_pe:
    input:
        unpack(get_fastq),
    output:
        r1=temp("results/trimmed/{sample}-{unit}.1.fastq.gz"),
        r2=temp("results/trimmed/{sample}-{unit}.2.fastq.gz"),
        r1_unpaired=temp("results/trimmed/{sample}-{unit}.1.unpaired.fastq.gz"),
        r2_unpaired=temp("results/trimmed/{sample}-{unit}.2.unpaired.fastq.gz"),
        trimlog="results/trimmed/{sample}-{unit}.trimlog.txt",
    params:
        **config["params"]["trimmomatic"]["pe"],
        extra=lambda w, output: "-trimlog {}".format(output.trimlog),
    log:
        "logs/trimmomatic/{sample}-{unit}.log",
    wrapper:
        "0.74.0/bio/trimmomatic/pe"


rule map_reads:
    input:
        reads=get_trimmed_reads,
        idx=rules.bwa_index.output,
    output:
        temp("results/mapped/{sample}-{unit}.sorted.bam"),
    log:
        "logs/bwa_mem/{sample}-{unit}.log",
    params:
        index=lambda w, input: os.path.splitext(input.idx[0])[0],
        extra=get_read_group,
        sort="samtools",
        sort_order="coordinate",
    threads: 8
    wrapper:
        "0.74.0/bio/bwa/mem"


rule mark_duplicates:
    input:
        "results/mapped/{sample}-{unit}.sorted.bam",
    output:
        bam=temp("results/dedup/{sample}-{unit}.bam"),
        metrics="results/qc/dedup/{sample}-{unit}.metrics.txt",
    log:
        "logs/picard/dedup/{sample}-{unit}.log",
    params:
        config["params"]["picard"]["MarkDuplicates"],
    wrapper:
        "0.74.0/bio/picard/markduplicates"


rule recalibrate_base_qualities:
    input:
        bam=get_recal_input(),
        bai=get_recal_input(bai=True),
        ref="resources/genome.fasta",
        dict="resources/genome.dict",
        known="resources/variation.noiupac.vcf.gz",
        known_idx="resources/variation.noiupac.vcf.gz.tbi",
    output:
        recal_table="results/recal/{sample}-{unit}.grp",
    log:
        "logs/gatk/bqsr/{sample}-{unit}.log",
    params:
        extra=get_regions_param() + config["params"]["gatk"]["BaseRecalibrator"],
    resources:
        mem_mb=1024,
    wrapper:
        "0.74.0/bio/gatk/baserecalibrator"


rule apply_base_quality_recalibration:
    input:
        bam=get_recal_input(),
        bai=get_recal_input(bai=True),
        ref="resources/genome.fasta",
        dict="resources/genome.dict",
        recal_table="results/recal/{sample}-{unit}.grp",
    output:
        bam=protected("results/recal/{sample}-{unit}.bam"),
    log:
        "logs/gatk/apply-bqsr/{sample}-{unit}.log",
    params:
        extra=get_regions_param(),
    resources:
        mem_mb=1024,
    wrapper:
        "0.74.0/bio/gatk/applybqsr"


rule samtools_index:
    input:
        "{prefix}.bam",
    output:
        "{prefix}.bam.bai",
    log:
        "logs/samtools/index/{prefix}.log",
    wrapper:
        "0.74.0/bio/samtools/index"
rule fastqc:
    input:
        unpack(get_fastq),
    output:
        html="results/qc/fastqc/{sample}-{unit}.html",
        zip="results/qc/fastqc/{sample}-{unit}.zip",
    log:
        "logs/fastqc/{sample}-{unit}.log",
    wrapper:
        "0.74.0/bio/fastqc"


rule samtools_stats:
    input:
        "results/recal/{sample}-{unit}.bam",
    output:
        "results/qc/samtools-stats/{sample}-{unit}.txt",
    log:
        "logs/samtools-stats/{sample}-{unit}.log",
    wrapper:
        "0.74.0/bio/samtools/stats"


rule multiqc:
    input:
        expand(
            [
                "results/qc/samtools-stats/{u.sample}-{u.unit}.txt",
                "results/qc/fastqc/{u.sample}-{u.unit}.zip",
                "results/qc/dedup/{u.sample}-{u.unit}.metrics.txt",
            ],
            u=units.itertuples(),
        ),
    output:
        report(
            "results/qc/multiqc.html",
            caption="../report/multiqc.rst",
            category="Quality control",
        ),
    log:
        "logs/multiqc.log",
    wrapper:
        "0.74.0/bio/multiqc"
rule get_genome:
    output:
        "resources/genome.fasta",
    log:
        "logs/get-genome.log",
    params:
        species=config["ref"]["species"],
        datatype="dna",
        build=config["ref"]["build"],
        release=config["ref"]["release"],
    cache: True
    wrapper:
        "0.74.0/bio/reference/ensembl-sequence"


checkpoint genome_faidx:
    input:
        "resources/genome.fasta",
    output:
        "resources/genome.fasta.fai",
    log:
        "logs/genome-faidx.log",
    cache: True
    wrapper:
        "0.74.0/bio/samtools/faidx"


rule genome_dict:
    input:
        "resources/genome.fasta",
    output:
        "resources/genome.dict",
    log:
        "logs/samtools/create_dict.log",
    conda:
        "../envs/samtools.yaml"
    cache: True
    shell:
        "samtools dict {input} > {output} 2> {log} "


rule get_known_variation:
    input:
        # use fai to annotate contig lengths for GATK BQSR
        fai="resources/genome.fasta.fai",
    output:
        vcf="resources/variation.vcf.gz",
    log:
        "logs/get-known-variants.log",
    params:
        species=config["ref"]["species"],
        build=config["ref"]["build"],
        release=config["ref"]["release"],
        type="all",
    cache: True
    wrapper:
        "0.74.0/bio/reference/ensembl-variation"


rule remove_iupac_codes:
    input:
        "resources/variation.vcf.gz",
    output:
        "resources/variation.noiupac.vcf.gz",
    log:
        "logs/fix-iupac-alleles.log",
    conda:
        "../envs/rbt.yaml"
    cache: True
    shell:
        "rbt vcf-fix-iupac-alleles < {input} | bcftools view -Oz > {output}"


rule tabix_known_variants:
    input:
        "resources/variation.noiupac.vcf.gz",
    output:
        "resources/variation.noiupac.vcf.gz.tbi",
    log:
        "logs/tabix/variation.log",
    params:
        "-p vcf",
    cache: True
    wrapper:
        "0.74.0/bio/tabix"


rule bwa_index:
    input:
        "resources/genome.fasta",
    output:
        multiext("resources/genome.fasta", ".amb", ".ann", ".bwt", ".pac", ".sa"),
    log:
        "logs/bwa_index.log",
    resources:
        mem_mb=369000,
    cache: True
    wrapper:
        "0.74.0/bio/bwa/index"


rule get_vep_cache:
    output:
        directory("resources/vep/cache"),
    params:
        species=config["ref"]["species"],
        build=config["ref"]["build"],
        release=config["ref"]["release"],
    log:
        "logs/vep/cache.log",
    wrapper:
        "0.74.0/bio/vep/cache"


rule get_vep_plugins:
    output:
        directory("resources/vep/plugins"),
    log:
        "logs/vep/plugins.log",
    params:
        release=config["ref"]["release"],
    wrapper:
        "0.74.0/bio/vep/plugins"
rule vcf_to_tsv:
    input:
        "results/annotated/all.vcf.gz",
    output:
        report(
            "results/tables/calls.tsv.gz",
            caption="../report/calls.rst",
            category="Calls",
        ),
    log:
        "logs/vcf-to-tsv.log",
    conda:
        "../envs/rbt.yaml"
    shell:
        "(bcftools view --apply-filters PASS --output-type u {input} | "
        "rbt vcf-to-txt -g --fmt DP AD --info ANN | "
        "gzip > {output}) 2> {log}"


rule plot_stats:
    input:
        "results/tables/calls.tsv.gz",
    output:
        depths=report(
            "results/plots/depths.svg", caption="../report/depths.rst", category="Plots"
        ),
        freqs=report(
            "results/plots/allele-freqs.svg",
            caption="../report/freqs.rst",
            category="Plots",
        ),
    log:
        "logs/plot-stats.log",
    conda:
        "../envs/stats.yaml"
    script:
        "../scripts/plot-depths.py"
