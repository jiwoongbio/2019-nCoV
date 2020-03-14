#!/bin/bash
# Author: Jiwoong Kim (jiwoongbio@gmail.com)

# Requirements
# 1. Perl: https://www.perl.org
# 2. BioPerl: http://www.bioperl.org/wiki/Main_Page
#    - Bio::DB::Fasta
#    - Bio::SeqIO
# 3. EMBOSS: http://emboss.sourceforge.net
#    - needle
#    - stretcher
# 4. Basic linux commands: bash, rm, gzip, sort, echo, find, sed, awk
# 5. lftp: http://lftp.yar.ru
# 6. BepiPred-2.0: http://www.cbs.dtu.dk/services/BepiPred/
# 7. netMHCpan-4.0: http://www.cbs.dtu.dk/services/NetMHCpan/
# 8. netMHCIIpan-3.2: http://www.cbs.dtu.dk/services/NetMHCIIpan/

# Download reference genome data files
lftp -c "mirror -p -L ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/858/895/GCF_009858895.2_ASM985889v3"

# Unzip reference genome and protein sequence files
gzip -dc GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_genomic.fna.gz > reference.genome.fasta
gzip -dc GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_protein.faa.gz > reference.protein.fasta

# Define reference protein coding regions
perl gff_extract.pl -f feature=CDS GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_genomic.gff.gz chromosome start end strand protein_id > reference.protein.coding_region.txt

# Build Annomen annotation table
git clone https://github.com/jiwoongbio/Annomen.git
perl Annomen/Annomen_table.pl GCF_009858895.2_ASM985889v3/GCF_009858895.2_ASM985889v3_genomic.gff.gz reference.genome.fasta reference.transcript.fasta reference.protein.fasta > Annomen/Annomen_table.txt 2> Annomen/Annomen_table.log

# B-cell epitope prediction
BepiPred-2.0 reference.protein.fasta > reference.BepiPred-2.0.txt

# MHC binding prediction
perl netMHCpan.pl reference.protein.fasta HLA-A01:01 > reference.netMHCpan.HLA-A01:01.txt
perl netMHCIIpan.pl reference.protein.fasta HLA-DPA10103-DPB10101 > reference.netMHCpan.HLA-DPA10103-DPB10101.txt

# Download query genome sequence file
perl esearch.pl nucleotide "MN975262.1[Accession]" | perl efetch.pl nucleotide - fasta text > genome.fasta

# Pairwise genome sequence alignment
perl alignment.position_base.pl -O 20 -E 0 reference.genome.fasta genome.fasta > genome.position_base.txt

# Identify genome variants
perl position_base.variant.pl genome.position_base.txt > genome.variant.txt

# Annotate genome variants using Annomen
perl Annomen/leftalignIndel.pl genome.variant.txt reference.genome.fasta | perl Annomen/sort_by_reference.pl - reference.genome.fasta 0 1 | perl Annomen/Annomen.pl - reference.genome.fasta Annomen/Annomen_table.txt reference.transcript.fasta reference.protein.fasta > genome.variant.annotated.txt

# Define protein coding regions and protein sequences
perl region.liftover.pl reference.protein.coding_region.txt genome.position_base.txt > protein.coding_region.txt
perl region.translate.pl -e protein.coding_region.txt genome.fasta > protein.fasta

# Pairwise protein sequence alignment
perl alignment.position_base.pl -d EBLOSUM62 -O 20 -E 0 reference.protein.fasta protein.fasta > protein.position_base.txt

# Identify protein variants
perl position_base.variant.pl -f 15 protein.position_base.txt > protein.variant.txt
awk -F'\t' -vOFS='\n' '{print ">"$1"|"$2"|0", $3, ">"$1"|"$2"|1", $4}' protein.variant.txt > peptide.fasta

# B-cell epitope prediction
BepiPred-2.0 protein.fasta > BepiPred-2.0.txt

# MHC binding prediction
perl netMHCpan.pl peptide.fasta HLA-A01:01 | sed 's/|/\t/' | sed 's/|/\t/' | awk -F'\t' -vOFS='\t' '{print $1, $2 + $4 - 1, $5, $6, $7, $3}' > netMHCpan.variant.HLA-A01:01.txt
perl netMHCIIpan.pl peptide.fasta HLA-DPA10103-DPB10101 | sed 's/|/\t/' | sed 's/|/\t/' | awk -F'\t' -vOFS='\t' '{print $1, $2 + $4 - 1, $5, $6, $7, $3}' > netMHCpan.variant.HLA-DPA10103-DPB10101.txt
