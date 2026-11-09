{smcl}
{* *! version 0.1.2  2026-11-09}{...}
{viewerjumpto "Syntax" "suppress##syntax"}{...}
{viewerjumpto "Description" "suppress##description"}{...}
{viewerjumpto "Options" "suppress##options"}{...}
{viewerjumpto "Remarks" "suppress##remarks"}{...}
{viewerjumpto "Stored results" "suppress##results"}{...}
{viewerjumpto "Examples" "suppress##examples"}{...}

{title:Title}

{p2colset 5 17 19 2}{...}
{p2col :{cmd:suppress} {hline 2}}Small-cell suppression for public-release tables{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:suppress} {it:countvar} {ifin}{cmd:,} {cmd:threshold(}{it:#}{cmd:)} [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
{synopt :{cmd:threshold(}{it:#}{cmd:)}}suppress cells with 1 <= count < {it:#}{p_end}

{syntab :Grouping}
{synopt :{cmd:by(}{it:varlist}{cmd:)}}protect published totals within each group of {it:varlist}{p_end}
{synopt :{cmd:complementary}}also blank further cells in any group whose total would reveal a suppressed cell{p_end}

{syntab :Output variables}
{synopt :{cmd:generate(}{it:newvar}{cmd:)}}numeric copy of {it:countvar} with suppressed cells set to missing{p_end}
{synopt :{cmd:flag(}{it:newvar}{cmd:)}}0 = not suppressed, 1 = primary, 2 = complementary{p_end}
{synopt :{cmd:gens(}{it:newvar}{cmd:)}}string copy for publication: {cmd:"<}{it:#}{cmd:"} for primary cells, {cmd:"*"} for complementary cells, the count otherwise{p_end}
{synoptline}

{pstd}
The data must be in long form, one observation per table cell, with the cell
count in {it:countvar} (for example, the output of {help contract} or
{help collapse}).


{marker description}{...}
{title:Description}

{pstd}
{cmd:suppress} automates the disclosure-control step that stands between a
tabulation and its public release.  It applies two rules.  {bf:Primary}
suppression blanks any cell whose count is at least 1 but below
{cmd:threshold()}, because a small cell is itself a disclosure.
{bf:Complementary} suppression (optional) closes the arithmetic back door:
if a group's total is published, a reader can subtract the visible cells and
may pin down a hidden value (always so with one blanked cell, and also, for
example, when two blanks under threshold 5 sum to 2, so both are 1).
{cmd:suppress} then blanks the next-smallest unsuppressed cell in that group,
repeating the check until no hidden small cell can be deduced.  Groups that
cannot be protected draw a warning rather than silent failure.

{pstd}
The command never alters {it:countvar} itself.  It reports what it found and
did, returns the counts in {cmd:r()}, and, on request, writes suppressed
copies of the counts to new variables ready for {help export excel},
{help putdocx}, {help collect}, or any other table export.


{marker options}{...}
{title:Options}

{phang}{cmd:threshold(}{it:#}{cmd:)} is required.  A cell is
primary-suppressed when 1 <= count < {it:#}.  Zero cells are {it:not}
suppressed: by default an empty cell reveals no individual (see
{it:Remarks}).  {it:#} must be a positive integer.  Non-integer (weighted)
counts are accepted, but the rule is applied as written: a count below 1,
such as 0.6, is {it:not} suppressed, and the deduction check used by
{cmd:complementary} reasons in whole counts, so its verdicts are
approximate for weighted tables.{p_end}

{phang}{cmd:by(}{it:varlist}{cmd:)} defines the groups whose published
totals must not reveal a suppressed cell; typically the column (or row)
identifier of the table, for example {cmd:by(industry)} or
{cmd:by(county year)}.  When {cmd:by()} is omitted, the whole sample is
treated as one group.  Cells with missing {cmd:by()} values are excluded
from the sample, so a pre-computed total row coded as missing is left
untouched.{p_end}

{phang}{cmd:complementary} turns on complementary suppression.  Within each
group, while the published total still lets a reader deduce a
primary-suppressed cell, the unsuppressed cell with the smallest count of at
least {it:#} is also suppressed (ties broken by data order).  The reader is
assumed to know the rule: each primary cell lies between 1 and {it:#}-1 and
each complementary cell is at least {it:#}.  A group is {it:protected} when
every hidden primary cell still has at least two possible values.  Zero
cells are never used as complements, because blanking a zero hides nothing:
the hidden cells then sum to less than {it:#}, which shows the blanked zero
is 0.  A group with no eligible cell left (a single cell, or only zeros
besides the suppressed ones) cannot be protected; {cmd:suppress} warns and
counts it in {cmd:r(n_unprotected)}.  Without {cmd:complementary}, the same
test marks such groups {it:AT RISK} in the report.  With {cmd:threshold(2)}
the mark {cmd:"<2"} already shows a primary cell is 1, so only a lone blank
draws a complement.{p_end}

{phang}{cmd:generate(}{it:newvar}{cmd:)} creates a numeric copy of
{it:countvar} with every suppressed cell set to missing.  Outside the
{cmd:if}/{cmd:in} sample the copy is missing too, so unchecked cells cannot
slip into a release.{p_end}

{phang}{cmd:flag(}{it:newvar}{cmd:)} creates a labeled byte variable:
0 = not suppressed, 1 = primary, 2 = complementary; missing outside the
sample.{p_end}

{phang}{cmd:gens(}{it:newvar}{cmd:)} creates a publication-ready string:
the count for visible cells, {cmd:"<}{it:#}{cmd:"} for primary cells, and
{cmd:"*"} for complementary cells.  Printing {cmd:"<}{it:#}{cmd:"} on a
complementary cell would be false (its count is not below the threshold),
so the two kinds carry different marks; footnote both in the released
table.{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Why zeros are left alone.}  A zero cell says no one in the group has the
characteristic, which identifies no individual, so it is not
primary-suppressed.  A zero is also never chosen as a complementary cell.
Blanking it gives no cover: the hidden cells would sum to the small cell's
own value, below the threshold, so a reader knows the blanked zero is 0 and
the small cell is the rest.  In the nlsw88 example below, Mining has a
college-grad count of 0 and a non-grad count of 4; the industry total of 4
reveals both, so {cmd:suppress} reports Mining as {it:NOT PROTECTED}.  For
such a group, suppress the group total itself, merge the group with a
neighbor, or raise the level of aggregation.  (Version 0.1.0 used the zero
as a complement and reported the group as protected.){p_end}

{pstd}
{bf:The single-blank trap.}  The most common disclosure error in a published
table is one suppressed cell against a visible total: the blank is not
hidden, it is defined, equal to the total minus the visible cells.  Running
{cmd:suppress} with {cmd:by()} and {cmd:complementary} is the automated
audit for exactly this.  Without {cmd:complementary}, the report still
flags every group left with a lone blank as {it:AT RISK}.{p_end}

{pstd}
{bf:Rates and denominators.}  This command suppresses counts.  For rates,
suppress the numerator and denominator counts first and show a rate only
where both survive; a denominator rule such as "no rate on fewer than 30"
is a second {cmd:suppress} run with {cmd:threshold(30)} on the
denominator.{p_end}

{pstd}
{bf:Limits.}  {cmd:suppress} protects one grouping dimension per run.  A
two-way table with both row and column totals published needs both
directions checked: run once with {cmd:by(}{it:colvar}{cmd:)} and once with
{cmd:by(}{it:rowvar}{cmd:)}, and blank the union.  Suppression guards a
single table; many overlapping releases from the same microdata can still
be combined by a determined analyst, which is the problem differential
privacy addresses.{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:suppress} stores in {cmd:r()}:{p_end}
{synoptset 22 tabbed}{...}
{synopt :{cmd:r(n_primary)}}number of primary-suppressed cells{p_end}
{synopt :{cmd:r(n_complementary)}}number of complementary-suppressed cells{p_end}
{synopt :{cmd:r(threshold)}}the threshold used{p_end}
{synopt :{cmd:r(N_cells)}}cells checked (sample size){p_end}
{synopt :{cmd:r(n_groups)}}number of {cmd:by()} groups{p_end}
{synopt :{cmd:r(n_unprotected)}}groups that could not be protected{p_end}
{synopt :{cmd:r(countvar)}}name of the count variable (macro){p_end}
{synopt :{cmd:r(by)}}the {cmd:by()} varlist (macro){p_end}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}Build a long-form cell table from {cmd:nlsw88} and suppress it
(threshold 5, protecting industry-column totals):{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. contract collgrad industry if industry <= 4, zero freq(n)}{p_end}
{phang2}{cmd:. suppress n, threshold(5) by(industry) complementary gens(n_pub)}{p_end}
{phang2}{cmd:. list collgrad industry n_pub, sepby(industry)}{p_end}

{pstd}Numeric output plus an audit flag, keeping the raw counts intact:{p_end}
{phang2}{cmd:. suppress n, threshold(5) by(industry) complementary generate(n_safe) flag(n_why)}{p_end}
{phang2}{cmd:. tabulate n_why}{p_end}

{pstd}Report only (no new variables), and use the returned counts:{p_end}
{phang2}{cmd:. suppress n, threshold(5) by(industry) complementary}{p_end}
{phang2}{cmd:. display r(n_primary) " primary + " r(n_complementary) " complementary cells hidden"}{p_end}

{pstd}Check a two-way table in both directions and blank the union:{p_end}
{phang2}{cmd:. suppress n, threshold(5) by(industry) complementary flag(f_col)}{p_end}
{phang2}{cmd:. suppress n, threshold(5) by(collgrad) complementary flag(f_row)}{p_end}
{phang2}{cmd:. generate n_pub2 = n if f_col == 0 & f_row == 0}{p_end}


{title:Author}

{pstd}
Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com), 2026.
MIT-licensed.{p_end}
