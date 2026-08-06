# Olfactory-search-on-psychedelics

Code from Welch, Gonzales-Hess, Tarvin, Connor, Smear, "The impact of a
psychedelic drug on olfactory search behavior by mice," bioRxiv
[2025.07.09.663970](https://www.biorxiv.org/content/10.1101/2025.07.09.663970v1).
`analysis/` contains the figure-generating code (R Markdown and MATLAB);
`nwb_conversion/` contains the script used to convert the raw session
data into NWB format.

Raw data is archived on DANDI: [dandiset 001863](https://dandiarchive.org/dandiset/001863).
The analysis scripts read from hardcoded paths on the original data
collection machine and will need path updates to run elsewhere.
