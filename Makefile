export SHELLOPTS:=errexit:pipefail
SHELL=/bin/bash  # required to make pipefail work
.SECONDARY:      # do not delete any intermediate files
.SECONDEXPANSION:

LOG = perl -ne 'use POSIX qw(strftime); $$|=1; print strftime("%F %02H:%02M:%S ", localtime), $$ARGV[0], "$@: $$_";'

SAMPLES=B47_0243 \
		B47_0245 \
		B47_0247 \
		B47_0249 \
		B47_0251 \
		B47_0244 \
		B47_0246 \
		B47_0248 \
		B47_0250 \
		B47_0252

all: coverage-read.pdf fastqc flagstat

#---
#--- READ COVERAGE
#---

coverage-read.pdf: $(foreach S, $(SAMPLES), $S.bedtools-genomecov.reads.txt) /mnt/projects/liquid/scripts/plot-coverage.R
	Rscript /mnt/projects/liquid/scripts/plot-coverage.R \
		--filename-suffix .bedtools-genomecov.reads.txt \
		--title-1 "Coverage" \
		--title-2 "Cumulative coverage" \
		--sort-point 6 \
		--max-coverage 30 \
		--output-pdf coverage-read.pdf.part \
		--output-png coverage-read.png.part
	mv coverage-read.pdf.part coverage-read.pdf
	mv coverage-read.png.part coverage-read.png

%.bedtools-genomecov.reads.txt: /mnt/projects/liquid/data/bam/%.rmdup.bam
	/data_synology/software/samtools-0.1.19/samtools view -b -F 1796 -q 1 $< chr20 \
		| /data_synology/software/bedtools-2.17.0/bin/bedtools genomecov \
			-ibam stdin \
			-g <(echo -e "chr20\t59505520\n") \
		| grep ^chr20 \
		> $@.part
	mv $@.part $@	

#---
#--- FRAGMENT COVERAGE
#---

coverage-fragment.pdf: $(foreach S, $(SAMPLES), $S.bedtools-genomecov.fragments.txt) /mnt/projects/liquid/scripts/plot-coverage.R
	Rscript /mnt/projects/liquid/scripts/plot-coverage.R \
		--filename-suffix .bedtools-genomecov.fragments.txt \
		--title-1 "Physical (fragment) coverage" \
		--title-2 "Cumulative physical (fragment) coverage" \
		--sort-point 18 \
		--max-coverage 30 \
		--output-pdf coverage-fragment.pdf.part \
		--output-png coverage-fragment.png.part
	mv coverage-fragment.pdf.part coverage-fragment.pdf
	mv coverage-fragment.png.part coverage-fragment.png
	
%.bedtools-genomecov.fragments.txt: /mnt/projects/liquid/data/bam/%.rmdup.bam
	/data_synology/software/samtools-0.1.19/samtools sort -@ 10 -no <(/data_synology/software/samtools-0.1.19/samtools view -bh -F 1792 -q 1 $< chr20) bla \
		| /data_synology/software/bedtools-2.17.0/bin/bamToBed -i stdin -bedpe \
		| cut -f 1,2,6 \
		| sort -k 1,1 \
		| /data_synology/software/bedtools-2.17.0/bin/bedtools genomecov \
			-i stdin \
			-g <(echo -e "chr20\t59505520\n") \
		| grep ^chr20 \
		> $@.part
	mv $@.part $@

#---
#--- FASTQC
#---

.PHONY: fastqc
fastqc: $(foreach S, $(SAMPLES), fastqc/$S.rmdup_fastqc.html)
	
fastqc/%.rmdup_fastqc.html: /mnt/projects/liquid/data/bam/%.rmdup.bam
	mkdir -p fastqc/$*.part
	/data_synology/software/FastQC-0.11.2/fastqc --outdir fastqc/$*.part --threads 5 $<
	mv fastqc/$*.part/* fastqc
	rmdir fastqc/$*.part

#---
#--- PICARD INSERT SIZE
#---
.PHONY: picard
picard: $(foreach S, $(SAMPLES), picard/$S.chr20.picard.insertsize.out)

picard/%.chr20.picard.insertsize.out: /mnt/projects/liquid/data/bam/%.rmdup.bam /data_synology/software/picard-tools-1.114/CollectInsertSizeMetrics.jar
	mkdir -p picard
	java -jar /data_synology/software/picard-tools-1.114/CollectInsertSizeMetrics.jar \
		INPUT=<(/data_synology/software/samtools-0.1.19/samtools view -bh -F 1792 -q 1 $< chr20) \
		HISTOGRAM_FILE=picard/$*.chr20.picard.insertsize.pdf \
		OUTPUT=$@.part \
		STOP_AFTER=10000000
	mv $@.part $@

#---
#--- SAMTOOLS FLAGSTAT
#---
.PHONY: flagstat
flagstat: $(foreach S, $(SAMPLES), flagstat/$S.chr20.samtools.flagstat)
flagstat/%.chr20.samtools.flagstat: /mnt/projects/liquid/data/bam/%.rmdup.bam
	mkdir -p flagstat
	/data_synology/software/samtools-0.1.19/samtools flagstat $< 2>&1 1>$@.part | $(LOG)
	mv $@.part $@
