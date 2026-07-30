*! version 0.1.0  06jul2026  Eric A. Booth, Sr Researcher, Texas 2036
*! suppress: primary and complementary small-cell suppression for
*!           public-release tables (long-form cell datasets)
*  version 16.0 is sufficient: no features newer than 16 are used.
program define suppress, rclass
    version 16.0
    syntax varname(numeric) [if] [in],           ///
        THREShold(numlist max=1 integer >=1)     ///
        [ BY(varlist) GENerate(name) FLAG(name)  ///
          GENS(name) COMPlementary ]

    local countvar `varlist'
    local k = `threshold'

    * ----- validate requested new variable names ------------------
    local newnames `generate' `flag' `gens'
    local dupchk : list dups newnames
    if `"`dupchk'"' != "" {
        di as err "generate(), flag(), and gens() must name distinct new variables"
        exit 198
    }
    foreach nv of local newnames {
        confirm new variable `nv'
    }

    * ----- mark the estimation sample ------------------------------
    * marksample drops observations with missing `countvar';
    * cells with missing by() values are also excluded.
    marksample touse
    if "`by'" != "" markout `touse' `by', strok
    qui count if `touse'
    if r(N) == 0 error 2000
    local ncells = r(N)

    * counts must be nonnegative
    qui count if `touse' & `countvar' < 0
    if r(N) > 0 {
        di as err "`countvar' contains `=r(N)' negative value(s) in the sample; cell counts must be nonnegative"
        exit 459
    }

    * ----- group id, original order, and primary suppression -------
    tempvar gid obsno prim comp
    qui gen long `obsno' = _n
    if "`by'" != "" {
        qui egen long `gid' = group(`by') if `touse'
        sort `obsno'                    // restore original order
    }
    else qui gen long `gid' = 1 if `touse'
    su `gid' if `touse', meanonly
    local G = r(max)

    * PRIMARY rule: suppress cells with 1 <= count < threshold.
    * Zero cells are not disclosive by default and are left alone.
    qui gen byte `prim' = `touse' & `countvar' >= 1 & `countvar' < `k'
    qui gen byte `comp' = 0

    * ----- per-group pass: complementary suppression + report ------
    local nunprot = 0
    local natrisk = 0
    tempname minv
    forvalues g = 1/`G' {

        * group label (first cell of the group, in original order)
        su `obsno' if `gid' == `g', meanonly
        local f = r(min)
        if "`by'" == "" local lab "(all cells)"
        else {
            local lab ""
            local sep ""
            foreach v of local by {
                capture confirm string variable `v'
                if !_rc local piece = `v'[`f']
                else {
                    local pval = `v'[`f']
                    capture local piece : label (`v') `pval'
                    if _rc local piece "`pval'"
                }
                local lab `"`lab'`sep'`piece'"'
                local sep " / "
            }
        }
        local lab_`g' = usubstr(`"`lab'"', 1, 25)

        qui count if `gid' == `g'
        local nc_`g' = r(N)
        qui count if `gid' == `g' & `prim'
        local np_`g' = r(N)
        local nk_`g' = 0

        if `np_`g'' == 0 local stat_`g' "clean"
        else if "`complementary'" == "" {
            if `np_`g'' == 1 {
                local stat_`g' "AT RISK"
                local ++natrisk
            }
            else local stat_`g' "primary only"
        }
        else {
            * COMPLEMENTARY rule: while the group holds exactly one
            * suppressed cell, its published total reveals that cell
            * by subtraction; blank the next-smallest unsuppressed
            * cell and re-check.
            local stat_`g' "protected"
            if `nc_`g'' < 2 {
                local stat_`g' "NOT PROTECTED"
                local ++nunprot
                di as txt `"warning: group {bf:`lab_`g''} has a suppressed cell but only `nc_`g'' cell; its published total would reveal the hidden value and no complementary cell exists"'
            }
            else {
                local nsupp = `np_`g''
                while `nsupp' == 1 {
                    qui count if `gid' == `g' & !`prim' & !`comp'
                    if r(N) == 0 {
                        local stat_`g' "NOT PROTECTED"
                        local ++nunprot
                        di as txt `"warning: group {bf:`lab_`g''} cannot be protected: no unsuppressed cell is left to blank"'
                        continue, break
                    }
                    su `countvar' if `gid' == `g' & !`prim' & !`comp', meanonly
                    scalar `minv' = r(min)
                    su `obsno' if `gid' == `g' & !`prim' & !`comp' ///
                        & `countvar' == scalar(`minv'), meanonly
                    qui replace `comp' = 1 if `obsno' == r(min)
                    local ++nsupp
                    local ++nk_`g'
                }
            }
        }
    }

    qui count if `prim'
    local nprim = r(N)
    qui count if `comp'
    local ncomp = r(N)

    * ----- report ---------------------------------------------------
    di as txt ""
    di as txt "Small-cell suppression" as res "  (threshold `k': blank cells with 1 <= count < `k')"
    di as txt "  cells checked              = " as res %8.0fc `ncells'
    di as txt "  primary suppressions       = " as res %8.0fc `nprim'
    if "`complementary'" != "" ///
        di as txt "  complementary suppressions = " as res %8.0fc `ncomp'
    if "`by'" != "" ///
        di as txt "  groups, by `by'" _col(30) "= " as res %8.0fc `G'

    local showall = (`G' <= 30)
    di as txt "{hline 70}"
    di as txt %-27s "group" %7s "cells" %9s "primary" %8s "compl." "  status"
    di as txt "{hline 70}"
    local hidden = 0
    forvalues g = 1/`G' {
        if !`showall' & `np_`g'' == 0 & `nk_`g'' == 0 {
            local ++hidden
            continue
        }
        di as txt %-27s `"`lab_`g''"' as res %7.0f `nc_`g'' ///
            %9.0f `np_`g'' %8.0f `nk_`g'' as txt "  `stat_`g''"
    }
    if `hidden' > 0 ///
        di as txt "  (`hidden' group(s) with no suppressions not listed)"
    di as txt "{hline 70}"
    if `nunprot' > 0 ///
        di as txt "warning: `nunprot' group(s) could not be protected; see messages above"
    if `natrisk' > 0 & "`complementary'" == "" ///
        di as txt "note: `natrisk' group(s) hold exactly one suppressed cell; a published group total would reveal it by subtraction. Consider option {bf:complementary}."

    * ----- requested output variables -------------------------------
    if "`generate'" != "" {
        qui gen `:type `countvar'' `generate' = `countvar' ///
            if `touse' & !`prim' & !`comp'
        label variable `generate' "`countvar', suppressed below `k'"
    }
    if "`flag'" != "" {
        qui gen byte `flag' = 0 if `touse'
        qui replace `flag' = 1 if `prim'
        qui replace `flag' = 2 if `comp'
        label define `flag' 0 "not suppressed" 1 "primary" ///
            2 "complementary", replace
        label values `flag' `flag'
        label variable `flag' "suppression flag (threshold `k')"
    }
    if "`gens'" != "" {
        qui gen str1 `gens' = ""
        qui replace `gens' = strofreal(`countvar', "%12.0g") ///
            if `touse' & !`prim' & !`comp'
        qui replace `gens' = "<`k'" if `prim'
        qui replace `gens' = "*" if `comp'
        label variable `gens' "`countvar' for publication (threshold `k')"
    }

    * ----- stored results --------------------------------------------
    return scalar threshold       = `k'
    return scalar N_cells         = `ncells'
    return scalar n_groups        = `G'
    return scalar n_primary       = `nprim'
    return scalar n_complementary = `ncomp'
    return scalar n_unprotected   = `nunprot'
    return local  countvar `countvar'
    return local  by `by'
end
