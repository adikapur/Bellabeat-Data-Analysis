-- Setting REGEX patterns for time and date formats.

SET @TIMESTAMP_REGEX = '^\d{2}-\d{2}-\d{4}[T ]\d{1,2}:\d{1,2}:\d{1,2}(\.\d{1,6})? *(([+-]\d{1,2}(:\d{1,2})?)|Z|UTC)?$';
SET @DATE_REGEX = '^\d{4}-(?:[1-9]|0[1-9]|1[012])-(?:[1-9]|0[1-9]|[12][0-9]|3[01])$';
SET @TIME_REGEX = '^\d{1,2}:\d{1,2}:\d{1,2}(\.\d{1,6})?$';

-- Setting variables for time of day/ day of week analyses
SET @MORNING_START = 6;
SET @MORNING_END = 12;
SET @AFTERNOON_END = 18;
SET @EVENING_END = 21;
-- Check to see which column names are shared across tables
SELECT 
    column_name, count(table_name)
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
GROUP BY column_name;
 -- We found that Id was a common column, let's make sure that it is in every table we have
SELECT 
    table_name,
    SUM(CASE
        WHEN column_name = 'Id' THEN 1
        ELSE 0
    END) AS has_id_column
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
GROUP BY 1
ORDER BY 1 ASC;
  -- This query checks to make sure that each table has a column of a date or time related type
 -- If your column types were detected properly prior to upload this table should be empty
SELECT 
    table_name,
    SUM(CASE
        WHEN data_type IN ('TIMESTAMP' , 'DATETIME', 'TIME', 'DATE') THEN 1
        ELSE 0
    END) AS has_time_info
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
        AND data_type IN ('TIMESTAMP' , 'DATETIME', 'DATE')
GROUP BY 1
HAVING has_time_info = 0;
 -- If we found that we have columns of the type DATETIME, TIMESTAMP, or DATE we can use this query to check for their names
SELECT 
    CONCAT(table_catalog,
            '.',
            table_schema,
            '.',
            table_name) AS table_path,
    table_name,
    column_name
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
        AND data_type IN ('TIMESTAMP' , 'DATETIME', 'DATE');
 -- We now know that every table has an "Id" column but we don't know how to join the dates
 -- If we find that not every table has a DATETIME, TIMESTAMP, or DATE column we use their names to check for what might be date-related
 -- Here we check to see if the column name has any of the keywords below:
 -- date, minute, daily, hourly, day, seconds
SELECT 
    table_name, column_name
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
        AND LOWER(column_name) REGEXP 'date|minute|daily|hourly|day|seconds';
 -- In the dailyActivity_merged table we saw that there is a column called ActivityDate, let's check to see what it looks like
 -- One way to check if something follows a particular pattern is to use a regular expression.
 -- In this case we use the regular expression for a timestamp format to check if the column follows that pattern.
 -- The is_timestamp column demonstrates that this column is a valid timestamp column
SELECT      ActivityDate,     
ActivityDate REGEXP @TIMESTAMP_REGEX AS is_timestamp 
FROM     bellabeat.dailyActivity_merged 
 -- To quickly check if all columns follow the timestamp pattern we can take the minimum value of the boolean expression across the entire table
SELECT 
    CASE
        WHEN MIN(ActivityDate REGEXP @TIMESTAMP_REGEX) = 1 THEN 'Valid'
        ELSE 'Not Valid'
    END AS valid_test
FROM
    bellabeat.dailyActivity_merged;
    
-- Say we want to do an analysis based on daily data, this could help us to find tables that might be at the day level
SELECT distinct table_name
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'bellabeat'
    AND LOWER(table_name) REGEXP 'day|daily';
    
-- Now that we have a list of tables, we should look at the columns that are shared among the tables
SELECT
    column_name,
    GROUP_CONCAT(DISTINCT table_name ORDER BY table_name) AS tables
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    table_schema = 'bellabeat'
    AND LOWER(table_name) REGEXP 'day|daily'
GROUP BY
    column_name
HAVING
    COUNT(DISTINCT table_name) > 1;

-- Now that we have a list of tables, we should look at the columns that are shared among the tables
-- We should also make certain that the data types align between tables
SELECT
  column_name,
  table_name,
  data_type
FROM
  INFORMATION_SCHEMA.COLUMNS
WHERE
  table_schema = 'bellabeat'
  AND LOWER(table_name) REGEXP 'day|daily'
  AND column_name IN (
    SELECT
      column_name
    FROM
      INFORMATION_SCHEMA.COLUMNS
    WHERE
      table_schema = 'bellabeat'
      AND LOWER(table_name) REGEXP 'day|daily'
    GROUP BY
      column_name
    HAVING
      COUNT(table_name) >= 2) -- BASICALLY FINDING TWO TABLES WITH ABOVE KEYWORD
ORDER BY
  1;
select * from dailyactivity_merged
-- joining tables with spefic columns using aliases 
SELECT
    A.Id,
    A.Calories,
    A.ActivityDate,
    A.TotalSteps,
    -- ... (include other columns as needed from table A)
    I.SedentaryMinutes,
    I.LightlyActiveMinutes,
    I.FairlyActiveMinutes,
    I.VeryActiveMinutes,
    I.SedentaryActiveDistance,
    I.LightActiveDistance,
    I.ModeratelyActiveDistance,
    I.VeryActiveDistance
FROM
    bellabeat.dailyActivity_merged A
LEFT JOIN
    bellabeat.dailyCalories_merged C ON A.Id = C.Id AND A.ActivityDate = C.ActivityDay AND A.Calories = C.Calories
LEFT JOIN
    bellabeat.dailyIntensities_merged I ON
    A.Id = I.Id
    AND A.ActivityDate = I.ActivityDay
    AND A.FairlyActiveMinutes = I.FairlyActiveMinutes
    AND A.LightActiveDistance = I.LightActiveDistance
    AND A.LightlyActiveMinutes = I.LightlyActiveMinutes
    AND A.ModeratelyActiveDistance = I.ModeratelyActiveDistance
    AND A.SedentaryActiveDistance = I.SedentaryActiveDistance
    AND A.SedentaryMinutes = I.SedentaryMinutes
    AND A.VeryActiveDistance = I.VeryActiveDistance
    AND A.VeryActiveMinutes = I.VeryActiveMinutes
LEFT JOIN
    bellabeat.dailySteps_merged S ON A.Id = S.Id AND A.ActivityDate = S.ActivityDay
LEFT JOIN
    bellabeat.sleepDay_merged Sl ON A.Id = Sl.Id AND A.ActivityDate = Sl.SleepDay;

  
  -- Say we are considering sleep related products as a possibility, let's take a moment to see if/how people nap during the day
-- To do this we are assuming that a nap is any time someone sleeps but goes to sleep and wakes up on the same day
-- Analysis based on the time of day and day of the week at a person level
SELECT
  hc.Id,
  CAST(hc.ActivityDateTime AS DATE) AS ActivityDate,
  CAST(hc.ActivityDateTime AS TIME) AS ActivityTime,
  DAYNAME(CAST(hc.ActivityDateTime AS DATE)) AS day_of_week,
  CASE
    WHEN DAYNAME(CAST(hc.ActivityDateTime AS DATE)) IN ('Sunday', 'Saturday') THEN 'Weekend'
    WHEN DAYNAME(CAST(hc.ActivityDateTime AS DATE)) IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday') THEN 'Weekday'
    ELSE 'ERROR'
  END AS part_of_week,
  CASE
    WHEN HOUR(CAST(hc.ActivityDateTime AS TIME)) BETWEEN 6 AND 11 THEN 'Morning'
    WHEN HOUR(CAST(hc.ActivityDateTime AS TIME)) BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN HOUR(CAST(hc.ActivityDateTime AS TIME)) BETWEEN 18 AND 21 THEN 'Evening'
    WHEN HOUR(CAST(hc.ActivityDateTime AS TIME)) >= 22 OR HOUR(CAST(hc.ActivityDateTime AS TIME)) <= 5 THEN 'Night'
    ELSE 'ERROR'
  END AS time_of_day,
  hc.Calories
FROM Temp_HourlyCalories hc;
#analysis done




