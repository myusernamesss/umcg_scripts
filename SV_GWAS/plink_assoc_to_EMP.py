import sys
import scipy.stats as st
import math
import gzip

empty_out_spl=["1","x","1","1","x","1","1","trans","A/T","A","0","x","0","0","0","0","x","0","0","0","0","0"]

fname = sys.argv[1]
pheno = sys.argv[2]
dataset = sys.argv[3]
if fname.endswith(".gz"):
    f = gzip.open(fname)
else:
    f = open(fname)

f.readline()
print("PValue\tSNPName\tSNPChr\tSNPChrPos\tProbeName\tProbeChr\tProbeCenterChrPos\tCisTrans\tSNPType\tAlleleAssessed\tOverallZScore\tDatasetsWhereSNPProbePairIsAvailableAndPassesQC\tDatasetsZScores\tDatasetsNrSamples\tIncludedDatasetsMeanProbeExpression\tIncludedDatasetsProbeExpressionVariance\tHGNCName\tIncludedDatasetsCorrelationCoefficient\tMeta-Beta (SE)\tBeta (SE)\tFoldChange\tFDR")
for l in f:
    spl = l.strip().split()
    p = float(spl[8])
    if p > 0.05:
        continue
    zscore = str(math.copysign(st.norm.ppf(p/2), float(spl[7])))
    empty_spl_cp = empty_out_spl[:]
    empty_spl_cp[0] = str(p)
    empty_spl_cp[1] = spl[1]
    empty_spl_cp[2] = spl[0]
    empty_spl_cp[3] = spl[2]
    empty_spl_cp[4] = pheno
    empty_spl_cp[16] = pheno 
    empty_spl_cp[10] = zscore
    empty_spl_cp[11] = dataset
    empty_spl_cp[12] = zscore
    empty_spl_cp[13] = spl[5]
    print ("\t".join(empty_spl_cp))






