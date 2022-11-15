# Test for gatk
# -s
# --rerun-incomplete \
# --use-envmodules \
# --keep-going

snakemake \
    --jobs 8 \
    --retries 1      \
    --use-conda       \
    --latency-wait 300 \
    --cluster '
        sbatch \
        --account=margit0 \
            --partition=standard \
        --nodes=1      \
        --cpus-per-task=3 \
        --mem-per-cpu=1g \
        --time=24:00:00 \
            --output logs/{rule}.{wildcards}.o \
            --error logs/{rule}.{wildcards}.e ' \
 	  # --mail-type=begin \
	  # --mail-type=end \
    	  # --mail-type=fail \
          # --mail-user=delpropo@umich.edu ' \



