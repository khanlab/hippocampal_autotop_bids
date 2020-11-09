import numpy as np
import json

#load bvals
bvals = np.loadtxt(snakemake.input[0])


#if just single bval (i.e. rev ph enc b0), then just set manually
if bvals.size == 1:
 
    out_dict = dict()
    shells = [np.around(bvals,-2).astype('int').tolist()]
    out_dict['shells'] = shells
    out_dict['vol_to_shell'] = shells
    out_dict['shell_to_vol'] = {str(shells[0]): [0]} #point to index 0

#otherwise try to find shells
else:
   
    shells = []

    # histogram is used to find number of shells, with anywhere from 10 to 100 bins
    #  want to use the highest number of bins that doesn't split up the shells
    #  so that the bin centers can then be used as the shell bvalues..

    for i,nbins in enumerate( np.arange(10,100,5) ):

        counts, bin_edges = np.histogram(bvals, bins=nbins )

        bin_lhs = bin_edges[:-1]
        bin_rhs = bin_edges[1:]
        bin_centers = (bin_lhs + bin_rhs) / 2

        shells.append(bin_centers[np.where(counts>0)])


    #get number of shells for each bin-width choice
    nshells = [len(s) for s in shells]

    print('nshells')
    print(nshells)

    #use the highest number of bins that still produces the minimal number of shells
    min_nshells = np.min(nshells)
    possible_shells = np.where(nshells == min_nshells)[0]
    chosen_shells = shells[possible_shells[-1]]

    #round to nearest 100
    chosen_shells = np.around(chosen_shells,-2).astype('int')

    print('chosen_shells')
    print(chosen_shells)

    #write to file
    #np.savetxt(snakemake.output[0],chosen_shells,fmt='%d')



    #get bval indices, by mindist to shell
    #bvals
    rep_shells = np.tile(chosen_shells,[len(bvals),1])
    rep_bvals = np.tile(bvals,[len(chosen_shells),1]).T

    print(rep_shells)
    print(rep_bvals)

    #abs diff between bvals and shells
    diff = np.abs(rep_bvals - rep_shells)
    shell_ind = np.argmin(diff,1)

    shell_ind = chosen_shells[shell_ind]

    #get a list of indices shells to vols
    shell_to_vol = dict()
    for shell in chosen_shells.tolist():
        shell_to_vol[shell] = np.where(shell_ind==int(shell))[0].tolist()

    #chosen_shell
    out_dict = dict()
    out_dict['shells'] = chosen_shells.tolist()
    out_dict['vol_to_shell'] = shell_ind.tolist()
    out_dict['shell_to_vol'] = shell_to_vol


#write to json, shells and their indices
with open(snakemake.output[0], 'w') as outfile:
    json.dump(out_dict, outfile,indent=4)


