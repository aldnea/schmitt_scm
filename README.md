# schmitt_scm

This project contains a partial R port (`scripts/analysis_marx.R`) of the main Stata code from the replication files of Magness and Makovi (2023), which was used for a partial replication of the main result of that paper. It also contains a modified version (`scripts/analysis_schmitt.R`) used to test the hypothesis that Carl Schmitt's academic canonization, which accelerated rapidly in the 1990s, is attributable to his association with critical theory and particularly with Walter Benjamin. Data files and results of both are contained in this repository. What follows is an informal writeup of the replication result and my original findings.

## Magness and Makovi (2023) replication 

Magness and Makovi, "The Mainstreaming of Marx" (*Journal of Political Economy*, 2023), use the synthetic control method to construct a counterfactual trajectory for Ngram mentions of the name "Karl Marx" over the period 1878-1932. With 1917 as the treatment year, their analysis demonstrates that, compared to a large set of other similar and/or canonical authors, the trajectory of Marx’s Ngram frequency was subject to a substantial treatment effect, suggesting that the 1917 Revolution (Marx being Lenin’s favorite thinker) was likely the primary cause of Marx's academic canonization after 1917. 

The R port in this repository was used for a partial replication of the main result of Magness and Makovi: the donor weights for Marx's synthetic control using the R script were 48.7% Ferdinand Lassalle, 33.1% Rodbertus, 7.2% Oscar Wilde, 6.1% Abraham Lincoln, and 1.5% Charles Darwin, with minor weight assigned to August Bebel, Eduard Bernstein, Pasteur, Ebbinghaus, Nietzsche, and Kelvin. The donor weights for Marx's synthetic control in Magness and Makovi were 52.0% Lassalle, 28.8% Rodbertus, 12.0% Wilde, and 0.2% Proudhon, with small weight assigned to Lincoln, Pasteur, and Kelvin. Hence, the top three donors using this script and in the original Magness and Makovi analysis are the same and in the same order, and other, less weighty donors are shared: Lincoln, Pasteur, and Kelvin. Marx's joint post-std p-value using the R script was 0.064, while the joint post-std p-value found by Magness Makovi was 0.047. 

Though there is nonnegligible difference between the numbers in both results, this is to be expected: Stata's ```synth``` package with the ```nested allopt``` flag, used by Magness and Makovi, avoids local minima in its optimizer calls by, first, calculating the weights on each indicator variable by regression (the V-matrix), using this matrix to optimize the donor weights, and then using these donor weights to optimize the weights on the indicator variables once again (an exceedingly computationally expensive process), and, second, by running this process using three different starting V-matrices. No such optimizer method is available in R's ```Synth``` package. Using any of the optimizers available in R's package, the initial V-matrix is the only V-matrix calculated per call, which massively reduces computational cost (no longer requiring a server-style computer), but increasing the likelihood of getting caught in local minima. Magness and Makovi note that, should any method other than ```nested allopt``` be used in Stata, only a partial replication is possible, but that any optimizer should produce a reasonably close result.

It should be noted that the large difference in the p-value can be misleading: as the joint post-std p-value is simply the portion of authors whose RMSPE ratio is greater than Marx's, it is highly sensitive to rank-order changes. In this case, Magness and Makovi's ```synth``` calls yielded 10 authors with RMSPE ratios greater than Marx's, while the ```Synth``` call using the script in this project yielded 12 such authors. With a difference of only 2 authors out of 226 non-Marx units in the ranked list, the results discussed are similar to those of Magness and Makovi. Indeed, there is only a 0.05% difference in RMSPE ratios between Marx and the nearest unit above him on the RMSPE ratio list, Jacobi, and a 9.7% difference in RMSPE ratios between Marx and the next unit above Jacobi, Aesop.

A more serious problem is the failure of several units’ ```Synth``` calls to converge. Even using the ```L-BFGS-B``` optimizer, which exhibited better ability to converge when units had out-of-range values on relatively collinear variables (for example authors whose year of major publication were premodern), the ```Synth``` calls for 10 units in the Magness and Makovi dataset failed to converge. If all 10 had post/pre RMSPE ratios greater than Marx’s, the p-value would rise to 0.11. This is a major caveat to these results and to the use of R’s ```Synth``` package for these sorts of analyses without clever tricks to force convergence. This limitation is discussed again in the Schmitt section below.

The analysis script takes as inputs CSV files containing cleaned per-year Ngram data for a large set of authors including Karl Marx from a window including the period 1878-1932 (`data/processed/ngrams_clean_marx.csv`) and containing labels of relevant predictors by author (political or not, socialist or not, year of first major publication, year of translation of first major work to English, did they write in English, did they write in German, did they write in French, etc.; `data/processed/author_labels_marx.csv`), edited from the original in the replication files of Magness and Makovi to remove Ngram data and retain only the labels. Over the window 1878-1932 and using 1917 as the treatment year, it produces a counterfactual trajectory of citation data for each author in the dataset by the synthetic control method using, as predictors, those labels and those Ngram frequency data. It then calculates a joint post-standardized p-value for Karl Marx, representing the portion of authors for whom the ratio of the post-treament RMSPE of their synthetic control and the pre-treatment RMSPE was greater than that ratio for Marx. A low joint post-std p-value represents a very extreme and (within the dataset) very unlikely deviation of post-treatment citations from what would be predicted by reference to other authors in the dataset, especially those similar to Marx. This project also contains the scraper script needed to produce the Ngram CSV (`scripts/scrape_ngrams_marx.py`) and the cleaner script used to prepare the data for analysis (`scripts/clean_ngrams_marx.py`), along with the summary table containing synthetic control outcomes, donor weights, V-weights found by the synthetic control, treated and synthetic weights by predictor, joint post-std p-value, and RMSPE ratios by author (`results/Treatment_Marx_1917/synth_results_1917.xlsx`) and a plot of Marx's synthetic trajectory and his actual trajectory over the period of interest (`results/Treatment_Marx_1917/synth_plot_1917.pdf`). The pre-cleaning Ngram file is also contained here (`data/raw/ngrams_raw_marx.csv`).

The plot of actual and synthetic trajectories from Magness and Makovi and from the script in this repository are below.

![Magness Makovi plot](https://github.com/aldnea/schmitt_scm/blob/main/m_m_plot.png?raw=true)
![1917 treatment](https://github.com/aldnea/schmitt_scm/blob/main/results/Treatment_Marx_1917/synth_plot_1917.jpg?raw=true)

## The Canonization of Carl Schmitt and Critical Theory: a Synthetic Control Analysis

I use the synthetic control method (SCM) approach of Magness and Makovi (2023) to evaluate whether the discussion of Carl Schmitt among critical theorists contributed appreciably to the canonization of Schmitt in English-language academia. This analysis is carried out with reference to important years in the history of the publication and reception of Walter Benjamin's correspondence with Schmitt.

Magness and Makovi (2023) apply the SCM to demonstrate that Karl Marx's canonization within academia was a result of the 1917 Russian Revolution acting as an exogenous shock to his reception. This research extends their work, examining intra-literary exogenous shocks to literary reception.

Using Google Ngram data as a proxy for intellectual influence, I construct counterfactual trajectories for Schmitt with treatment years 1974, 1994, and 1965. The rationale for these years is as follows: 1974 is when the first publications of Benjamin’s correspondence began in German. Though the collected correspondence (including the Schmitt letter) was published in 1978, 1974 is chosen to avoid confounding from early academic discussion of the editing, as Magness and Makovi reason with their choice of 1917 rather than 1922, the end of the Civil War, for their treatment year. 1994 saw the publication of Benjamin's correspondence in English. Lastly, 1965 is used to check robustness, as it is a year when no treatment effect is expected and when no operation of the hypothesized mechanism is plausible. Using these counterfactuals, I test whether Schmitt’s reception diverges meaningfully from each counterfactual (e.g., what would have happened in the absence of the editing and publication events after 1974).

Relevant files in this repository are the Ngram scraper (`scripts/scrape_ngrams_schmitt.py`) and Ngram file cleaner (`scripts/clean_ngrams_schmitt.py`), the R analysis code (`scripts/analysis_schmitt.R`), the raw and cleaned tables of Ngrams (`data/raw/ngrams_raw_schmitt.csv`, `data/processed/ngrams_clean_schmitt.csv`), the table of predictor labels by author (`data/processed/author_labels_schmitt.csv`), the results summary tables (`results/Treatment_[YEAR]/synth_results_[YEAR].xlsx`), plots of Schmitt's counterfactual trajectories against his actual trajectory (`results/Treatment_[YEAR]/synth_plot_[YEAR].pdf`), and JPEG images of those plots (`results/Treatment_[YEAR]/synth_plot_[YEAR].jpg`).

## Research Question

Carl Schmitt (1888-1985) was a German jurist and political and legal theorist whose enthusiastic support of National Socialism made him both a peripheral figure in postwar German and Anglophone academia and an object of intellectual curiosity. By the 1980s, his full-throated defense of authoritarianism — his concepts of the state of exception and the friend-enemy distinction, his view of the authority of the sovereign, and his critique of parliamentary and liberal democracy — had established for him a minor, solid reputation in political and legal theory. Scholarly interest in him was sustained by his historical association with the amply-researched Weimar and Nazi periods and the German Conservative Revolution.

In 1978, academics were shocked by the publication in German of Walter Benjamin's correspondence, in which he, a Jewish luminary of the Frankfurt School, writes enthusiastically to Schmitt. Schmitt was no longer to be peripherally associated with Benjamin (appearing as a citation in the latter's _Ursprung des deutschen Trauerspiels_) — by all appearances, Schmitt was a non-negligible intellectual influence on a philosopher who had become one of the leading thinkers of the 20th century, and a leftist philosopher to boot.

A cursory look at the Google Ngram data for Schmitt demonstrates a first substantial spike in interest in the 1980s, followed by a much steeper spike in interest in the 1990s. Pursuant to this, I test whether Benjamin's correspondence may have produced a measurable discontinuity in Schmitt's Ngram trajectory, employing a synthetic control constructed from comparable thinkers.

It would be consistent with the hypothesis that Benjamin's correspondence generated interest in Schmitt if relevant years in the editing and publication history of Benjamin’s correspondence can be understood to have had a treatment effect on Schmitt’s reputation (i.e. on his Ngram mention frequency). Particularly, it would be consistent with the hypothesis if there are large treatment effects in 1994, when Benjamin's correspondence was published in English; a modest treatment effect in 1974, when Benjamin’s correspondence was undergoing editing and was first published in part in German, and when, in the post-treatment window from 1974 to 1993, discussion about the correspondence would have slowly diffused into English-language academia; and no appreciable treatment effect in 1965, when no treatment effect is expected and before the hypothesized mechanism could plausibly have operated, to test robustness.

## Data

**Outcome variable:** Google Ngram frequency for "Carl Schmitt" in the English (2019) corpus, 1945-2019. Ngram frequency measures the proportion of all words in Google's corpus of digitized books that the search phrase constitutes per year. Raw data is scraped via the Google Ngrams web interface and stored unmodified in `data/raw/`.

**Donor Pool:** 240 authors selected according to the following criteria:
- All authors in Magness and Makovi's list of authors not excluded according to the criteria mentioned below
- Conservative Revolution thinkers (necessarily requiring English translation), whose reception is plausibly independent of the growth of critical theory's popularity (e.g. Ernst Jünger, Werner Sombart, Oswald Spengler)
- Contemporaneous thinkers requiring English translation (e.g. Ernst Cassirer, Heinrich Rickert)
- Canonical Western philosophers with stable trajectories of English reception (e.g. Durkheim, Mill, Tocqueville)
- Contemporaneous Anglophone political theorists and sociologists (e.g. Isaiah Berlin, Quentin Skinner, Raymond Aron)

Excluded from the donor pool were thinkers excessively associated with Benjamin or with critical theory, whose trajectories would be necessarily impacted by the trajectory of critical theory's popularity and reception (Hegel, the young-Hegelians, Eugen Dühring, Marx, Nietzsche, Kant, Heidegger, Husserl).

## Method

The synthetic control method (Abadie and Gardeazabal 2003; Abadie, Diamond, and Hainmueller 2010) constructs a weighted average of untreated donor units, the pre-treatment trajectory of which should match the treated unit as closely as possible. The weights are selected by optimization on the sum of squared pre-treatment residuals. Post-treatment divergence between the treated unit and its synthetic counterfactual is interpreted as an estimate of the treatment effect.

**Pre-treatment windows:** 1950–1973, 1950-1993, with robustness check using 1950-1964.

**Post-treatment windows:** 1974-1993, 1994-2016, with robustness check using 1965-1973, representing the effect of the treatment up to the next treatment year of interest.

**Predictors for ```Synth```:** ```"Political"``` (is the author primarily referenced or known for work relevant to political studies; follows the tagging of Magness and Makovi); ```"ConservativeRevolution"``` (is the author associated with the German Conservative Revolution principally); ```"YearofPublication"``` (year of first major publication); ```"YearofTranslationtoEnglish"``` (year major publication was first translated to English); ```"OriginalLanguage"``` (original language of major publication); ```"wrote_English"```; ```"wrote_German"```; ```"wrote_French"```; ```"wrote_Spanish"```; ```"wrote_Italian"```; ```"wrote_Greek"```; ```"wrote_Latin"```.

These predictors are, where possible, taken directly from Magness and Makovi with only minor emendations: Kropotkin's ```"OriginalLanguage"``` flag is changed to French and his ```"wrote_French"``` flag is changed to 1. This was an error in their coding, as _The Conquest of Bread_ was originally written and published in French.

**Special Predictors for ```Synth```:** Ngram frequency averaged over three-year bins with three-year gaps between them, covering the total window.

**Inference:** Statistical significance is assessed via in-space placebo tests (Abadie et al. 2010): the SCM is rerun for every donor unit as if it were the treated unit, generating a distribution of placebo gaps. The p-value is the fraction of units — including Schmitt — whose ratio of synthetic post-treatment root mean squared percent error to synthetic pre-treatment RMSPE is at least as large as Schmitt's. With 240 donor units, the minimum p-value possible is $\frac{1}{\text{total units whose Synth calls converge}}=\frac{1}{240}≈0.0042$. The minimum possible is often greater, as the ```Synth``` calls of some units fail to converge.

**Implementation:** R, using `Synth` package (Abadie et al. 2011). Analysis follows Magness and Makovi (2023) with the following modifications: several robustness checks are omitted; optimizers available in the Stata ```synth``` package are unavailable in the R ```Synth``` package; optimizer method ```L-BFGS-B``` employed.

## Results

The synthetic control is composed, for all treatment years, primarily of Edgar Jung and Arthur Moeller van der Bruck, which acts as a good sanity check for the method; the fact that Conservative Revolution thinkers were selected is an encouraging sign that the method is producing a desirable synthetic control. The synthetic control fits Schmitt's pre-treatment trajectory closely for all three treatment years (pre-treatment RMSPE 1974: 1.8e-04; pre-treatment RMSPE 1994: 6.1e-04; pre-treatment RMSPE 1965: 1.7e-04). After both treatment years of interest, actual Schmitt diverges substantially from synthetic Schmitt. In the post-treatment period for 1974, actual Schmitt exceeds synthetic Schmitt by 203.3% on average, with a post/pre RMSPE ratio of 9.0. In the post-treatment period for 1994, actual Schmitt exceeds synthetic Schmitt by 198.0%, with a post/pre ratio of 14.5 — both comparable to benchmark SCM results in the literature. In other words, with both 1974 and 1994 as the treatment year, actual Schmitt was mentioned roughly three times as often as his synthetic control. On the other hand, for 1965, actual Schmitt is within only 11.7% of synthetic Schmitt, with a post/pre ratio of 1.4.

In-space placebo tests yield p = 0.029 for 1974, p = 0.0050 for 1994, and p = 0.41 for 1965. These results are consistent with the hypothesis that Benjamin's reception history had a major impact on Schmitt's canonization. With a 1974 treatment year, the treatment effect is well below the conventional threshold of significance, exhibiting a modest treatment effect compared to other units within the dataset. With 1994 as the treatment yaer, the treatment effect is massive: a p-value of 0.0050 represents Schmitt having the single most extreme post/pre RMSPE ratio in the dataset. 

The backdating robustness test setting the placebo treatment date to 1965 — before any plausible operation of the hypothesized mechanism — shows no systematic post-placebo divergence, confirming that the 1974 and 1994 results are not an artefact of poor pre-treatment fit, nor are likely to be spurious.

The ```L-BFGS-B``` optimizer is chosen as it converges most often when dealing with units whose predictors are out of range in variables that exhibit strong collinearity, for example if their year of first publication is premodern. However, even with this optimizer, the ```Synth``` calls failed for several units in all treatments, including in the Marx replication. At worst, the ```Synth``` calls of 13 units failed to converge with 1994 as the treatment year. If all 13 had a post/pre RMSPE ratio greater than Schmitt's, the joint post-std p-value would rise to 0.065. This should be interpreted as a major caveat to these results and a limitation on performing these sorts of analyses without access to an optimizer similar to the ```nested allopt``` flags in Stata's `Synth` package. This merits further investigation, as Magness and Makovi's claim that alternative optimizers should produce similar results was in reference to Stata's ecosystem, where even the simpler optimizers differ from those available in R's ```Synth``` package. Further investigation is required to determine how great of an impact this has on the results: a server style computer using the ```nested allopt``` flags with Stata’s ```synth``` package would yield more reliable results, but so might clever tricks to force convergence.

These results are illustrated here.
![1974 treatment](https://github.com/aldnea/schmitt_scm/blob/main/results/Treatment_1974/synth_plot_1974.jpg?raw=true)
![1994 treatment](https://github.com/aldnea/schmitt_scm/blob/main/results/Treatment_1994/synth_plot_1994.jpg?raw=true)
![1965 treatment](https://github.com/aldnea/schmitt_scm/blob/main/results/Treatment_1965/synth_plot_1965.jpg?raw=true)

## Limitations

**Donor pool constraints.** One could always come up with new authors who, had they been added to the list, might have approximated the treated unit well and contributed to the treated unit's synthetic control in a meaningful way. This list of authors is by no means comprehensive, nor is necessarily optimal, and judgment calls had to be made on exclusions.

**Confounding channels.** While these results certainly show that something is anomalous about the trajectory of conversation about Carl Schmitt after 1974 and 1994, anomalous even by comparison with a set of similar thinkers and a wide range of other authors besides, what exactly caused this cannot be distinguished by this method alone. It may be safely said that these results are _consistent_ with the hypothesis that Benjamin had a major role on Schmitt's trajectory, but the data admits alternate explanations, and further research using alternate methods would be required to distinguish among competing hypotheses. For example, maybe the rapid rise of conversation about Schmitt is attributable to the fall of the Berlin Wall. The 1974 and 1994 treatment effects should be understood as capturing the effect of events that happened in those years or thereafter, and certainly Walter Benjamin's relationship with Schmitt was discussed during those periods; however, alternate hypotheses remain tenable.

**Pre-treatment gap.** For the 1994 treatment year, actual and synthetic Schmitt exhibit visual divergences in the late 80s and early 90s. However, these pre-treatment gaps are below the conventional threshold of significance for only one year at the peak of the spike in the late 80s, 1987 (p = 0.005; see the per-year p-values printed by ```analysis_schmitt.R```). This spike is certainly highly anomalous, but it is the "odd one out," and the gaps between actual and synthetic stabilize below significance afterward; the extremity of the gaps do not appear to be systemic. What causes this anomaly and what impact it has on the interpretability of the results merits further investigation. 

**Failure to converge.** The failure of the ```Synth``` calls for many units to converge, discussed in more detail in the Results section, is a substantial caveat to these results. More investigation is required to evaluate the actual effect of this on the joint post-std p-value that would be produced by an ideal optimizer. The actual p-value could in theory be anywhere from 0.0047 to 0.065.

## How to Reproduce

Marx:
1. Clone the repository
2. Install R dependencies: `Synth`, `tidyverse`, `here`, `writexl`, `parallel`, `future.apply`, `progressr`
3. Install Python dependencies: `requests`, `pandas`
4. Run `scripts/scrape_ngrams_marx.py` to collect raw Ngram data
5. Run `scripts/clean_ngrams_marx.py` to produce the analysis-ready dataset
6. Run `scripts/analysis_marx.R` to reproduce all results and figures

All outputs are saved to ```results/Treatment_Marx_[YEAR]```.

Schmitt:
1. Clone the repository
2. Install R dependencies: `Synth`, `tidyverse`, `here`, `writexl`, `parallel`, `future.apply`, `progressr`
3. Install Python dependencies: `requests`, `pandas`
4. Run `scripts/scrape_ngrams_schmitt.py` to collect raw Ngram data
5. Run `scripts/clean_ngrams_schmitt.py` to produce the analysis-ready dataset
6. Run `scripts/analysis_schmitt.R` to reproduce all results and figures

All outputs are saved to `results/Treatment_[YEAR]`.

## References

Abadie, A., Diamond, A., and Hainmueller, J. (2010). Synthetic control methods 
for comparative case studies. *Journal of the American Statistical Association*, 
105(490), 493–505.

Abadie, A., Diamond, A., and Hainmueller, J. (2011). Synth: An R package for 
synthetic control methods in comparative case studies. *Journal of Statistical 
Software*, 42(13).

Abadie, A. and Gardeazabal, J. (2003). The economic costs of conflict: A case 
study of the Basque Country. *American Economic Review*, 93(1), 113–132.

Magness, P.W. and Makovi, M. (2023). The mainstreaming of Marx: Measuring the 
effect of the Russian Revolution on Karl Marx's influence. *Journal of Political 
Economy*, 131(6).
