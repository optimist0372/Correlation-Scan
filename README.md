# Correlation-Scan

Correlation scan is a statistical framework developed to estimate local genetic correlations between two traits based on fixed window size in a fixed sliding window. The framework uses BLUP solution of SNP effects to estimate these local genetic correlations. In addition, correlation scan can identify drivers and antagonizing regions affecting trait correlations; the driver regions has the same  local correlation estimates, positive or negative, as the global genetic correlation; in antagonizing windows it is the opposite. 

![Anurag's GitHub stats](https://github-readme-stats.vercel.app/api?username=optimist0372&theme=dark&show_icons=true)


---
title: "LAVA TUTORIAL"
author: "Josefin Werme (j.werme@vu.nl), Christiaan de Leeuw (c.a.de.leeuw@vu.nl), CTG Lab, VU Amsterdam"
date: "`r Sys.Date()`"
output: 
  rmarkdown::github_document:
    math_method: NULL
vignette: >
  %\VignetteIndexEntry{tutorial}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

This tutorial shows you how to read in and analyse data with LAVA (**L**ocal **A**nalysis of [co]**V**ariant **A**ssociation): A tool developed for local genetic correlation (*r*~g~) analysis.

LAVA can analyse the standard bivariate local *r*~g~ between two phenotypes (binary as well as continuous), and account for known or estimated sample overlap. It can also test the univariate local genetic signal for all phenotypes of interest (i.e. the local *h*^2^), which may be used to filter out non-associated loci. In addition, it can model the local genetic relations between multiple phenotypes simultaneously using two possible conditional models: partial correlation and multiple regression (for more details, see the [LAVA paper](https://www.nature.com/articles/s41588-022-01017-y)).

The tutorial will show you how to install and run LAVA using some example input data. If you wish, you can inspect the data in the 'vignettes/data' folder.
