# suppress

Small-cell suppression for public-release tables in Stata.

A table cell that holds only a few people is a disclosure risk: publish it
and a reader may identify the individuals behind it. The usual release rule
is to blank any cell with a count below a threshold (often 5 or 10). But
blanking alone is not enough. If a group's total is published and only one
cell in the group is blank, the hidden value is just the total minus the
visible cells. `suppress` automates both steps: **primary** suppression
blanks every cell with a count of at least 1 but below the threshold, and
**complementary** suppression (optional) blanks the next-smallest cell in
any group whose total would let a reader deduce a blanked cell (a lone
blank, or blanks whose sum pins them down, such as two blanks summing to 2
under threshold 5), re-checking until no hidden small cell can be deduced
and warning about groups that cannot be protected.

The command works on plain long-form datasets, one observation per table
cell with the count in a variable, which is what `contract` or `collapse`
produce. It never changes the raw counts. It prints a per-group report,
returns the suppression counts in `r()`, and on request writes three kinds
of output variables: a numeric copy with suppressed cells set to missing, a
0/1/2 audit flag, and a publication-ready string that prints `<5`-style
markers for primary cells and `*` for complementary ones. Zero cells are
not suppressed, since an empty cell identifies no one, and they are never
used as complementary cells, since blanking a zero hides nothing (the help
file discusses the edge cases).

## Install

From GitHub:

```stata
net install suppress, from("https://raw.githubusercontent.com/ericabooth/suppress-stata-public/main/") replace force
help suppress
```

Requires Stata 16.0 or later. No dependencies.

## Quick start

```stata
sysuse nlsw88, clear
contract collgrad industry if industry <= 4, zero freq(n)
suppress n, threshold(5) by(industry) complementary gens(n_pub)
list collgrad industry n_pub, sepby(industry)
```

`n_pub` now prints `<5` where a cell was below the threshold, `*` where a
second cell was blanked to protect an industry total, and the count
everywhere else. The printed report shows, per industry, how many cells
were checked, blanked, and whether the group is protected. In this example
Mining is reported as NOT PROTECTED: its cells are 4 and 0, so the industry
total reveals both, and no cell can be blanked to hide them.

Full syntax:

```stata
suppress countvar [if] [in], threshold(#) [by(varlist) generate(newvar)
    flag(newvar) gens(newvar) complementary]
```

## Stored results

| Result                | Meaning                                        |
| --------------------- | ---------------------------------------------- |
| `r(n_primary)`        | cells blanked for being below the threshold    |
| `r(n_complementary)`  | cells blanked to protect a group total         |
| `r(threshold)`        | the threshold used                             |
| `r(N_cells)`          | cells checked (sample size)                    |
| `r(n_groups)`         | number of `by()` groups                        |
| `r(n_unprotected)`    | groups that could not be protected (warned)    |
| `r(countvar)`         | name of the count variable (macro)             |
| `r(by)`               | the `by()` varlist (macro)                     |

## Notes and limits

- One grouping dimension is protected per run. For a two-way table with
  both row and column totals published, run once with `by(colvar)`, once
  with `by(rowvar)`, and blank the union of the flags (example in the help
  file).
- Suppression protects a single table. Many overlapping releases from the
  same microdata can still be combined by a determined analyst; that is the
  problem differential privacy addresses.
- Counts must be nonnegative; cells with missing counts or missing `by()`
  values are excluded from the check. Non-integer (weighted) counts are
  accepted, but the rule is applied as written: a count below 1 (such as
  0.6) is not suppressed, and the deduction check reasons in whole
  counts, so its verdicts are approximate for weighted tables.

## Changes

- **0.1.2 (2026-11-09):** `gens()` prints float counts without storage
  noise (0.6, not .6000000238). The help and README now say how
  non-integer (weighted) counts are handled. The test battery finds the
  package folder itself and puts it first on the adopath.
- **0.1.1 (2026-11-09):** a group is reported as protected only when no
  hidden primary cell can be deduced from the group total. 0.1.0 stopped
  adding complementary cells as soon as a group had two blanks, so two
  blanks summing to 2 (both must be 1), or a blank of 1 next to a
  complement of 5 under threshold 5, were reported as protected. 0.1.0 also
  chose zero cells as complements; a blanked zero hides nothing, so groups
  such as Mining in the help example (cells 4 and 0) were reported as
  protected when the total revealed both cells. Zeros are no longer
  complements, and a group with nothing else to blank is reported as NOT
  PROTECTED and counted in `r(n_unprotected)`. Without `complementary`, the
  same test now decides which groups are AT RISK.

## License

MIT. Copyright (c) 2026 Eric A. Booth. See `LICENSE`.
