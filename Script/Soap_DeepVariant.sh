read -p " enter your Reference:" Re1
read -p " enter the Read 1:" r1
read -p " enter the Read 2:" r2
#indexing
2bwt-builder "$Re1"
#Alignment
soap -a Data/"$r1" -b Data/"$r2" -D "$Re1".index -o output/"$r1"/"$r1"_soap.soap -2 output/"$r1"/"$r1"_soap_SE.soap
#soap to SAM conversion
perl soap2sam.pl output/"$r1"/"$r1"_soap_SE.soap > output/"$r1"/"$r1"_soap.sam
#Bam_File
samtools view -bT output/"$r1"/"$r1"_soap.sam -o output/"$r1"/"$r1"_soap.bam
#Sort_Bam
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar SortSam VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1"_soap.bam O=output/"$r1"/"$r1"_Sort_soap.bam SORT_ORDER=coordinate
#Pcr_Duplicates
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar MarkDuplicates VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1"_Sort_soap.bam O=output/"$r1"/"$r1"_PCR_soap.bam REMOVE_DUPLICATES=true M=output/"$r1"/"$r1"_pcr_soap.metrics
#ID_Addition
java -Xmx10g -jar Tools/picard-tools-1.141/picard.jar AddOrReplaceReadGroups VALIDATION_STRINGENCY=SILENT I=output/"$r1"/"$r1"_PCR_soap.bam O=output/"$r1"/"$r1"_RG_soap.bam SO=coordinate RGID=SRR"$r1" RGLB=SRR"$r1" RGPL=illumina RGPU=SRR"$r1" RGSM=SRR"$r1" CREATE_INDEX=true
#Variant_Calling-Deep_Variant
MODEL=DeepVariant-inception_v3-0.4.0+cl-174375304.data-wgs_standard/model.ckpt
OUTPUT_DIR="$r1"_soap
mkdir -p "${OUTPUT_DIR}"
LOGDIR=./soap_logs
N_SHARDS=10
mkdir -p "${LOGDIR}"
time seq 0 $((N_SHARDS-1)) | parallel --eta --halt 2 --joblog "${LOGDIR}/log" --res "${LOGDIR}" python bin/make_examples.zip  --mode calling --ref "$Re1" --reads output/"$r1"/"$r1"_RG_soap.bam --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" --task {}
python bin/call_variants.zip --outfile output/"$r1"/soap_Deep_"$r1".gz --examples "${OUTPUT_DIR}/examples.tfrecord@${N_SHARDS}.gz" --checkpoint "${MODEL}"
python bin/postprocess_variants.zip --ref "$Re1" --infile output/"$r1"/soap_Deep_"$r1".gz --outfile output/"$r1"/soap_Deep_"$r1".vcf
#variant_Sepration_Indel_SNV
vcftools --vcf output/"$r1"/soap_Deep_"$r1".vcf --remove-indels --recode --recode-INFO-all --out output/"$r1"/soap_Deep_SNP_"$r1".vcf
vcftools --vcf output/"$r1"/soap_Deep_"$r1".vcf --keep-only-indels  --recode --recode-INFO-all --out output/"$r1"/soap_Deep_Indels_"$r1".vcf
