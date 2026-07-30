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
any group that would otherwise leak a lone blank through its total,
re-checking until each group is safe and warning about groups too small to
protect.

The command works on plain long-form datasets, one observation per table
cell with the count in a variable, which is what `contract` or `collapse`
produce. It never changes the raw counts. It prints a per-group report,
returns the suppression counts in `r()`, and on request writes three kinds
of output variables: a numeric copy with suppressed cells set to missing, a
0/1/2 audit flag, and a publication-ready string that prints `<5`-style
markers for primary cells and `*` for complementary ones. Zero cells are
not suppressed by default, since an empty cell identifies no one (the help
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
were checked, blanked, and whether the group is protected.

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
  values are excluded from the check.

## License

MIT. Copyright (c) 2026 Eric A. Booth. See `LICENSE`.
