-- ============================================================
-- PROJECT: Iowa Industry Wage & Employment Analysis
-- AUTHOR: Namarig Mohammed
-- DATE: June 2026
-- TOOLS: SQLiteStudio, SQLite
-- DATA SOURCE: Iowa QCEW (data.gov)
-- ============================================================

-- QUERY 1: DATASET OVERVIEW
-- Shows data range, record count, and industry coverage
SELECT 
    COUNT(*) as total_records,
    MIN(calendar_year) as earliest_year,
    MAX(calendar_year) as latest_year,
    COUNT(DISTINCT industry) as total_industries,
    COUNT(DISTINCT description) as industry_descriptions
FROM wages;

-- QUERY 2: TOP 10 HIGHEST-PAYING INDUSTRIES (LATEST QUARTER)
-- Identifies premium wage sectors in Iowa
SELECT 
    description as industry,
    calendar_year as year,
    quarter,
    ROUND(AVG(average_wage), 2) as avg_weekly_wage,
    ROUND(AVG(average_wage) * 52, 0) as avg_annual_wage,
    SUM(average_emp) as total_employment
FROM wages
WHERE area_type = '0'
  AND industry != '10'
  AND calendar_year = (SELECT MAX(calendar_year) FROM wages)
  AND quarter = (SELECT MAX(quarter) FROM wages WHERE calendar_year = (SELECT MAX(calendar_year) FROM wages))
GROUP BY description, calendar_year, quarter
HAVING total_employment > 1000
ORDER BY avg_weekly_wage DESC
LIMIT 10;

-- QUERY 3: FASTEST GROWING INDUSTRIES BY EMPLOYMENT
-- Year-over-year employment growth with sanity checks
WITH yearly_emp AS (
    SELECT 
        description as industry,
        calendar_year as year,
        SUM(average_emp) as total_emp
    FROM wages
    WHERE area_type = '0'
      AND industry != '10'
    GROUP BY description, calendar_year
),
growth AS (
    SELECT 
        industry,
        year,
        total_emp,
        LAG(total_emp) OVER (PARTITION BY industry ORDER BY year) as prev_emp,
        ROUND(
            ((total_emp - LAG(total_emp) OVER (PARTITION BY industry ORDER BY year)) 
            / LAG(total_emp) OVER (PARTITION BY industry ORDER BY year)) * 100,
            2
        ) as yoy_growth_pct
    FROM yearly_emp
)
SELECT *
FROM growth
WHERE prev_emp IS NOT NULL
  AND prev_emp > 5000
  AND total_emp > 5000
  AND ABS(yoy_growth_pct) < 100
ORDER BY yoy_growth_pct DESC
LIMIT 15;

-- QUERY 4: FASTEST GROWING INDUSTRIES BY WAGE
-- Year-over-year wage growth with small-industry filter
WITH yearly_wages AS (
    SELECT 
        description as industry,
        calendar_year as year,
        ROUND(AVG(average_wage), 2) as avg_wage
    FROM wages
    WHERE area_type = '0'
      AND industry != '10'
    GROUP BY description, calendar_year
),
wage_growth AS (
    SELECT 
        industry,
        year,
        avg_wage,
        LAG(avg_wage) OVER (PARTITION BY industry ORDER BY year) as prev_wage,
        ROUND(
            ((avg_wage - LAG(avg_wage) OVER (PARTITION BY industry ORDER BY year)) 
            / LAG(avg_wage) OVER (PARTITION BY industry ORDER BY year)) * 100,
            2
        ) as wage_growth_pct
    FROM yearly_wages
)
SELECT *
FROM wage_growth
WHERE prev_wage IS NOT NULL
  AND prev_wage > 500
ORDER BY wage_growth_pct DESC
LIMIT 15;

-- QUERY 5: INDUSTRY EMPLOYMENT SHARE (ECONOMIC STRUCTURE)
-- Shows which industries dominate Iowa's economy
WITH latest AS (
    SELECT 
        description as industry,
        SUM(average_emp) as total_emp,
        SUM(wages) as total_wages
    FROM wages
    WHERE area_type = '0'
      AND industry != '10'
      AND calendar_year = (SELECT MAX(calendar_year) FROM wages)
      AND quarter = (SELECT MAX(quarter) FROM wages WHERE calendar_year = (SELECT MAX(calendar_year) FROM wages))
    GROUP BY description
),
totals AS (
    SELECT SUM(total_emp) as state_total_emp,
           SUM(total_wages) as state_total_wages
    FROM latest
)
SELECT 
    l.industry,
    l.total_emp,
    ROUND((l.total_emp * 100.0 / t.state_total_emp), 2) as pct_of_total_emp,
    ROUND((l.total_wages * 100.0 / t.state_total_wages), 2) as pct_of_total_wages
FROM latest l
CROSS JOIN totals t
ORDER BY l.total_emp DESC
LIMIT 15;