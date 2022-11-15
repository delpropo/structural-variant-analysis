# Test for gatk
# -s
# --rerun-incomplete \
# --use-envmodules \
# --keep-going

snakemake \
    -c 1 \
    --jobs 1   \
    --retries 1  \
    --use-conda       \
    --latency-wait 60 \
    --cluster '
        sbatch \
        --account=margit0 \
            --partition=debug \
        --nodes=1      \
        --cpus-per-task=4 \
        --mem-per-cpu=2g \
        --time=2:00:00 \
            --output logs/{rule}.{wildcards}.o \
            --error logs/{rule}.{wildcards}.e ' \
 	  # --mail-type=begin \
	  # --mail-type=end \
    	  # --mail-type=fail \
          # --mail-user=delpropo@umich.edu ' \



