#!/bin/bash
#  exports gemini.db database to gemini.db.txt file
#  database schema: https://gemini.readthedocs.io/en/latest/content/database_schema.html#the-variants-table
#  when using v.chr = g.chr AND v.gene = g.gene it becomes very slow
#  by default bcbio writes PASS only variants to the database

#  example call: cre.gemini2txt.sh S28-ensemble.db 5 ALL

#PBS -l walltime=1:00:00,nodes=1:ppn=1
#PBS -joe .
#PBS -d .
#PBS -l vmem=10g,mem=10g

if [ -z $file ]
then
    file=$1
fi

#10 reads for WES 5 reads for RNA-seq
depth_threshold=$2

severity_threshold=$3
echo $severity_threshold

gemini query -q "select name from samples" $file > samples.txt

sQuery="select
	v.variant_id as Variant_id,
        v.ref as Ref,
        v.alt as Alt,
        v.impact as Variation,
        v.depth as Depth,
        v.qual as Quality,
        v.gene as Gene,
        g.ensembl_gene_id as Ensembl_gene_id,
        v.clinvar_sig as Clinvar,
        v.transcript as Ensembl_transcript_id,
        v.aa_length as AA_position,
        v.exon as Exon,
        v.pfam_domain as Pfam_domain,
        v.rs_ids as rsIDs,
        v.aaf_1kg_all as Maf_1000g,
        v.aaf_gnomad_all as Gnomad_maf,
        v.max_aaf_all as Maf_all,
        v.gnomad_num_het as Gnomad_het,
        v.exac_num_het as Exac_het,
        v.gnomad_num_hom_alt as Gnomad_hom_alt,
        v.sift_score as Sift_score,
        v.polyphen_score as Polyphen_score,
        v.cadd_scaled as Cadd_score,gts,
        v.chrom as Chrom,
        v.start+1 as Pos,
        v.aa_change as AA_change,
        v.vep_hgvsc as Codon_change,
        v.aaf_esp_aa as EVS_maf_aa,
        v.aaf_esp_ea as EVS_maf_ea,
        v.aaf_esp_all as EVS_maf_all,
        v.is_conserved as Conserved_in_29_mammals,"

while read sample;
do
	sQuery=$sQuery"gts."$sample","
	sQuery=$sQuery"gt_alt_depths."$sample","
	sQuery=$sQuery"gt_depths."$sample","
done < samples.txt

# gene_detailed may contain 2 records per single transcript - because of synonymous gene names, and some genes may have None in the name,for example TSRM
# https://groups.google.com/forum/#!topic/gemini-variation/U3uEvWCzuQo
# v.depth = 'None' see https://github.com/chapmanb/bcbio-nextgen/issues/1894

if [[ "$severity_threshold" == 'ALL' ]]
then
#used for RNA-seq = 20k variants in the report
    severity_filter=""
#use for WES = 1k variants in the report
else
    severity_filter="and v.impact_severity<>'LOW'"
fi

sQuery=$sQuery"v.vep_hgvsc as Nucleotide_change_ensembl,
		v.vep_hgvsp as Protein_change_ensembl 
		from variants v, gene_detailed g
	        where 
	        v.transcript=g.transcript and 
	        (v.gene=g.gene or g.gene is NULL) "$severity_filter" and 
	        v.max_aaf_all < 0.01 and 
	        (v.depth >= "$depth_threshold" or v.depth = '' or v.depth is null)"

echo $sQuery
gemini query --header -q "$sQuery" $file > ${file}.txt;
