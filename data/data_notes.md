# Data

This project uses the provided `NARIET_Index_Constituents.xlsx` file for REIT names, ticker symbols, first-letter groups, and market capitalization values.

The file is not included in this public repository because it was provided as course material. To reproduce the project, place the file in the project root or in the `data/` folder and update the script path if needed.

The script downloads historical adjusted close prices from Yahoo Finance using `quantmod::getSymbols()`.

Main data inputs:

- NAREIT index constituents file
- Market capitalization values as of December 31, 2025
- Yahoo Finance adjusted close prices
- Weekly simple returns from December 31, 2023 to December 7, 2025
- Daily simple returns from December 8, 2025 to January 2, 2026
