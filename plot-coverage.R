library(optparse)

option_list <- list(
		make_option("--filename-suffix", type="character", help="Suffix of filenames that should be plotted"),
		make_option("--title-1", type="character", help="Title of first plot"),
		make_option("--title-2", type="character", help="Title of second plot"),
		make_option("--sort-point", type="integer", help="Coverage at which samples are sorted for legend"),
		make_option("--max-coverage", type="integer", help="Maximum value of x axis"),
		make_option("--output-pdf", type="character", help="PDF output file name"),
		make_option("--output-png", type="character", help="PNG output file name")
		)
opt <- parse_args(OptionParser(option_list=option_list))

# Assumes you've already run coverageBed -hist, and grep'd '^all'. E.g. something like:
# find *.bam | parallel 'bedtools -abam {} -b capture.bed -hist | grep ^all > {}.all.txt'

# Get a list of the bedtools output files you'd like to read in
files <- list.files(path="/mnt/projects/liquid/results", pattern=paste0(opt$'filename-suffix', '$'))
labs <- sapply(strsplit(files, ".", fixed=T), "[[", 1) # extract sample name from file name

# Create lists to hold coverage and cumulative coverage for each alignment,
# and read the data into these lists.
cov <- list()
cov_cumul <- list()
means <- numeric(0)
for (i in 1:length(files)) {
	cov[[i]] <- read.table(paste0("/mnt/projects/liquid/results/", files[i]))
	cov_cumul[[i]] <- 1-cumsum(cov[[i]][,5])
	means[i] <- cov_cumul[[i]][opt$'sort-point']
}

# Pick some colors
# Ugly:
# cols <- 1:length(cov)
# Prettier:
# ?colorRampPalette
# display.brewer.all()
library(RColorBrewer)
#cols <- brewer.pal(length(cov), "Dark2")
cols <- rainbow(length(cov))
ltypes <- rep(1:6,length.out=length(cov))

do_plot <- function(lwidth) {
	# Create plot area, but do not plot anything. Add gridlines and axis labels.
	layout(matrix(c(1,2,3,3), ncol = 2), widths = c(0.75, 0.25))

	plot(cov[[1]][1:(opt$'max-coverage'+1),2], cov[[1]][1:(opt$'max-coverage'+1),5], type='n', xlab="Coverage", ylab="Percentage of chr20 bases covered", ylim=c(0,0.5), main=opt$'title-1', xaxt="n", yaxt="n")
	abline(v = seq(0,opt$'max-coverage',1), col = "gray60", lty=3)
	abline(h = seq(0, 0.5, 0.05), col = "gray60", lty=3)
	axis(1, at=0:opt$'max-coverage', cex.axis=0.7)
	axis(2, at=seq(0, 0.5, 0.05))
	for (i in 1:length(cov)) {
		points(cov[[i]][1:(opt$'max-coverage'+1), 2], cov[[i]][1:(opt$'max-coverage'+1),5], type='b', lwd=lwidth, lty=ltypes[i], pch=ltypes[i]+14, col=cols[i])
	}
	
	par()
	plot(cov[[1]][1:(opt$'max-coverage'+1), 2], c(1,cov_cumul[[1]][1:opt$'max-coverage']), type='n', xlab="Coverage", ylab="Percentage of chr20 bases >= coverage", ylim=c(0,1.0), main=opt$'title-2', xaxt="n", yaxt="n")
	abline(v = seq(0,opt$'max-coverage',1), col = "gray60", lty=3)
	abline(h = seq(0, 1, 0.1), col = "gray60", lty=3)
	axis(1, at=0:opt$'max-coverage', cex.axis=0.7)
	axis(2, at=seq(0, 1, 0.1))
	for (i in 1:length(cov)) {
		points(cov[[i]][1:(opt$'max-coverage'+1), 2], c(1,cov_cumul[[i]][1:opt$'max-coverage']), type='b', lwd=lwidth, lty=ltypes[i], pch=ltypes[i]+14, col=cols[i])
	}
	
	# Add a legend using the nice sample labeles rather than the full filenames.
	par(mar=c(0, 0, 6, 0), cex=0.7)
	plot(0:1, 0:1, type="n", axes=F, ann=F)
	legend("topleft", legend=labs[order(means, decreasing=T)], col=cols[order(means, decreasing=T)], lwd=lwidth, lty=ltypes[order(means, decreasing=T)], pch=ltypes[order(means, decreasing=T)]+14, ncol=1)	
}

# Save the graph to a file
png(opt$'output-png', h=4000, w=2500, pointsize=40)
do_plot(3)
dev.off()

pdf(opt$'output-pdf', h=15, w=11)
do_plot(1.2)
dev.off()
