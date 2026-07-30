* test_suppress.do -- test battery for the suppress package
* Run in batch from a scratch directory:  stata-mp -b do test_suppress.do
* Judge by the log: no r-numbered errors, no failed asserts.
* ---------------------------------------------------------------------
* All paths live in globals set here; nothing below is hard-coded.
global pkgroot "/Users/ebooth/Documents/GitHub/Book Manuscript:Applied Evaluation-Stata/suppress-stata-public"

version 16.0
clear all
set more off
set seed 20260706
adopath + "$pkgroot"
which suppress

* =====================================================================
* Test 1: hand-built table (the book's worked example, known by hand)
*   collgrad x goods-producing industry, threshold 5:
*   primary   = grad/Ag (3), notgrad/Mining (4), grad/Constr (3)
*   complem.  = notgrad/Ag (14), grad/Mining (0), notgrad/Constr (26)
*   untouched = both Manufacturing cells (334, 33)
* =====================================================================
clear
input byte collgrad byte industry long n
0 1  14
0 2   4
0 3  26
0 4 334
1 1   3
1 2   0
1 3   3
1 4  33
end
label define ind 1 "Ag" 2 "Mining" 3 "Construction" 4 "Manufacturing"
label values industry ind

suppress n, threshold(5) by(industry) complementary ///
    generate(n_pub) flag(fl) gens(n_str)
local r_thr  = r(threshold)
local r_np   = r(n_primary)
local r_nc   = r(n_complementary)
local r_N    = r(N_cells)
local r_G    = r(n_groups)
local r_unp  = r(n_unprotected)
assert `r_thr' == 5
assert `r_np'  == 3
assert `r_nc'  == 3
assert `r_N'   == 8
assert `r_G'   == 4
assert `r_unp' == 0

* exact per-cell assertions (hand-derived)
assert fl == 1 if collgrad==1 & industry==1     // grad/Ag = 3
assert fl == 1 if collgrad==0 & industry==2     // notgrad/Mining = 4
assert fl == 1 if collgrad==1 & industry==3     // grad/Constr = 3
assert fl == 2 if collgrad==0 & industry==1     // notgrad/Ag = 14
assert fl == 2 if collgrad==1 & industry==2     // grad/Mining = 0
assert fl == 2 if collgrad==0 & industry==3     // notgrad/Constr = 26
assert fl == 0 if industry==4                   // Manufacturing clean
* numeric output: suppressed -> missing, others copied unchanged
assert missing(n_pub) if fl > 0
assert n_pub == n     if fl == 0
* string output: "<5" primary, "*" complementary, count otherwise
assert n_str == "<5"  if fl == 1
assert n_str == "*"   if fl == 2
assert n_str == "334" if collgrad==0 & industry==4
assert n_str == "33"  if collgrad==1 & industry==4

* =====================================================================
* Test 2: same table built live from nlsw88 (the chapter's test bed);
*   confirms the raw counts match the book, then the same suppression
* =====================================================================
sysuse nlsw88, clear
keep if industry <= 4 & !missing(collgrad, industry)
contract collgrad industry, zero freq(n)
assert n == 14  if collgrad==0 & industry==1
assert n == 4   if collgrad==0 & industry==2
assert n == 26  if collgrad==0 & industry==3
assert n == 334 if collgrad==0 & industry==4
assert n == 3   if collgrad==1 & industry==1
assert n == 0   if collgrad==1 & industry==2
assert n == 3   if collgrad==1 & industry==3
assert n == 33  if collgrad==1 & industry==4

suppress n, threshold(5) by(industry) complementary flag(fl)
local r_np = r(n_primary)
local r_nc = r(n_complementary)
assert `r_np' == 3
assert `r_nc' == 3
assert fl == 0 if industry==4
assert fl >  0 if industry <4

* =====================================================================
* Test 3: one-cell group cannot be protected -> warning + counter
* =====================================================================
clear
input str1 g long n
"A"  3
"B" 10
"B" 20
end
suppress n, threshold(5) by(g) complementary flag(fl)
local r_np  = r(n_primary)
local r_nc  = r(n_complementary)
local r_unp = r(n_unprotected)
assert `r_np'  == 1
assert `r_nc'  == 0
assert `r_unp' == 1
assert fl == 1 if g=="A"
assert fl == 0 if g=="B"

* =====================================================================
* Test 4: two primaries in a group need no complementary cell
* =====================================================================
clear
input str1 g long n
"A"  2
"A"  3
"A" 50
"B"  7
"B"  8
end
suppress n, threshold(5) by(g) complementary flag(fl)
local r_np = r(n_primary)
local r_nc = r(n_complementary)
assert `r_np' == 2
assert `r_nc' == 0
assert fl == 1 if n <  5
assert fl == 0 if n >= 5

* =====================================================================
* Test 5: without complementary, only primary suppression happens
* =====================================================================
clear
input byte collgrad byte industry long n
0 1  14
0 2   4
1 1   3
1 2   0
end
suppress n, threshold(5) by(industry) flag(fl)
local r_np = r(n_primary)
local r_nc = r(n_complementary)
assert `r_np' == 2
assert `r_nc' == 0
qui count if fl == 2
assert r(N) == 0

* =====================================================================
* Test 6: no by() -> the whole sample is one group
* =====================================================================
clear
input long n
3
7
9
end
suppress n, threshold(5) complementary flag(fl) gens(s)
local r_G  = r(n_groups)
local r_np = r(n_primary)
local r_nc = r(n_complementary)
assert `r_G'  == 1
assert `r_np' == 1
assert `r_nc' == 1
assert fl == 1 if n==3          // primary
assert fl == 2 if n==7          // next-smallest becomes complementary
assert fl == 0 if n==9
assert s  == "9" if n==9

* =====================================================================
* Test 7: zero cells are not disclosive (not primary-suppressed)
* =====================================================================
clear
input long n
0
10
20
end
suppress n, threshold(5) complementary
local r_np = r(n_primary)
local r_nc = r(n_complementary)
assert `r_np' == 0
assert `r_nc' == 0

* =====================================================================
* Test 8: if/in restriction; excluded cells stay untouched/missing
* =====================================================================
clear
input byte collgrad byte industry long n
0 1  14
0 2   4
0 3  26
0 4 334
1 1   3
1 2   0
1 3   3
1 4  33
end
suppress n if industry <= 3, threshold(5) by(industry) complementary ///
    generate(np) flag(fl) gens(ns)
local r_N = r(N_cells)
assert `r_N' == 6
assert missing(np) if industry==4
assert missing(fl) if industry==4
assert ns == ""    if industry==4
assert fl >  0     if industry <4     // all 6 in-sample cells blanked

* =====================================================================
* Test 9: non-integer counts follow the documented rule
*   (1 <= count < threshold suppressed; values below 1 left alone)
* =====================================================================
clear
input double n
2.5
0.4
12
end
suppress n, threshold(5) flag(fl)
local r_np = r(n_primary)
assert `r_np' == 1
assert fl[1] == 1
assert fl[2] == 0
assert fl[3] == 0

* =====================================================================
* Test 10: deliberate error cases (capture; assert the exit codes)
* =====================================================================
clear
input long n
3
7
end
* (a) threshold() is required -> r(198)
capture suppress n
assert _rc == 198
* (b) generate() must be a new variable -> r(110)
capture suppress n, threshold(5) generate(n)
assert _rc == 110
* (c) duplicate new-variable names -> r(198)
capture suppress n, threshold(5) generate(x) flag(x)
assert _rc == 198
* (d) negative counts -> r(459)
qui replace n = -1 in 1
capture suppress n, threshold(5)
assert _rc == 459
* (e) string countvar rejected by syntax -> r(109)
qui replace n = 3 in 1
gen str3 s = "abc"
capture suppress s, threshold(5)
assert _rc == 109

di as res _n "ALL SUPPRESS TESTS PASSED"
