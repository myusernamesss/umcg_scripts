#!/bin/bash

module load PLINK
module load Metal

type=dSV
d=/data/umcg-tifn/SV/SV_GWAS/

sv=$1
snp=$2
echo "sv=$sv, snp=$snp"
sp=`grep -w "$sv" ${d}/data/sv_name_conversion_table.txt | cut -f4 | uniq`
all_zscores=()
all_pvals=()

meta_out_dir=${d}/results/${type}/meta/${sv}/
meta_out_filebase=${meta_out_dir}/${sv}-${snp}.meta_res
mkdir -p ${d}/results/${type}/meta/${sv}/

metal_script=/data/umcg-tifn/SV/SV_GWAS/scripts/metal_per_sv/${sv}.metal.txt
cat /data/umcg-tifn/SV/SV_GWAS/scripts/metal_header.txt > $metal_script

# check in which cohorts the SV is present
IFS=',' read -ra cohorts_with_sv <<< `grep -w $sv ${d}/data/dSV_per_cohort.txt | cut -f6`

for cohort in ${cohorts_with_sv[@]}
do
    echo -e "\n\nRunning the analysis for ${cohort}\n\n"

    res_dir=${d}/results/${type}/${cohort}/${sv}/
    mkdir -p ${res_dir}/permutations/

    geno_file=${d}/genotypes/${cohort}/${cohort}_filtered
    perm_fam_dir=${d}/genotypes/${cohort}/permuted/
    pheno_file=${d}/data/${cohort}.${type}.filtered.txt
    covar_file=${d}/data/${cohort}.covariates.txt

    covars="age,read_number,$sp,PC1,PC2"
    if [ $cohort == "DAG3" ]
    then
        echo "DAG3! Use PCs 1-5"
        covars="age,read_number,$sp,PC1,PC2,PC3,PC4,PC5"
    fi

    #
    # run real GWAS analysis
    #
    plink2 \
        --glm sex hide-covar \
        --bfile ${geno_file} \
        --pheno ${pheno_file} \
        --pheno-name "${sv}" \
        --covar ${covar_file} \
        --covar-name "${covars}" \
        --covar-variance-standardize \
        --out ${res_dir}/${type}.${cohort}.${sv}.${snp} \
        --snp ${snp}
    plink_returncode=$?
    if [ ! $plink_returncode -eq 0 ]
    then
        all_zscores+=( "NA" )
        all_pvals+=( "NA" )
    else
        z=`head -2 ${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic | tail -1 | awk '{print $11}'`
        all_zscores+=( $z )
        pval=`head -2 ${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic | tail -1 | awk '{print $12}'`
        all_pvals+=( $pval )
        # format the assoc results for METAL: add A1 and A2
        awk '{OFS="\t"}; {if ($6 == $4) {oa=$5}; if ($6 == $5) {oa=$4}; if (NR == 1) {oa="A2"}; {print $1,$2,$3,$6, oa, $7,$8,$9,$10,$11,$12}}' \
        ${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic | gzip -c > ${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic.gz
        
        rm ${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic

        echo -e "PROCESS\t${res_dir}/${type}.${cohort}.${sv}.${snp}.${sv}.glm.logistic.gz\n" >> $metal_script
    fi
done
#
# Run meta-analysis
#
echo -e "OUTFILE\t${meta_out_filebase} .tbl\nANALYZE HETEROGENEITY\nQUIT" >> $metal_script
metal $metal_script

het_pval=`cut -f11 ${meta_out_filebase}1.tbl | tail -n+2`

cohorts_joined=`printf -v var '%s,' "${cohorts_with_sv[@]}"; echo "${var%,}"`
zscores_joined=`printf -v var '%s,' "${all_zscores[@]}"; echo "${var%,}"`
pvals_joined=`printf -v var '%s,' "${all_pvals[@]}"; echo "${var%,}"`

echo -e "$zscores_joined $pvals_joined $het_pval"

