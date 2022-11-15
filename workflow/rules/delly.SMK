


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
        "v1.18.3/bio/delly"