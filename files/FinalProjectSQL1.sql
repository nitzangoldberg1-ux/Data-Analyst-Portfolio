DROP DATABASE IF EXISTS video_games;
CREATE DATABASE video_games;
;

USE video_games
GO
;

DROP TABLE IF EXISTS video_games

CREATE TABLE video_games (
 Name varchar(MAX)
,Platform varchar(MAX)
,Year_of_Release varchar(MAX)
,Genre varchar(MAX)
,Publisher varchar(MAX)
,NA_Sales float
,EU_Sales float
,JP_Sales float
,Other_Sales float
,Global_Sales float
,Critic_Score float
,Critic_Count float
,User_Score float
,User_Count float
,Developer varchar(MAX)
,Rating varchar(MAX)
)
;


BULK INSERT video_games
FROM 'C:\FinalProjectSql\Video_Games_Sales_2016.txt' -- add the path to your CSV file
WITH
(
    FIRSTROW = 2, -- as 1st one is header
    FIELDTERMINATOR = '\t',  --TSV field delimiter
    ROWTERMINATOR = '\n',   --Use to shift the control to next row
    TABLOCK)



SELECT * FROM video_games



--2--
--a--
SELECT COUNT (*) AS GamesWith3PlusPlatforms
FROM(
SELECT Name,COUNT(*) AS CountPlatforms
FROM video_games
GROUP BY Name
HAVING COUNT(*)>=3
) AS T

--b--
WITH GenereYearSales AS (
    SELECT 
        Genre,
        Year_of_Release,
        SUM(Global_Sales) AS Total_Global_Sales
        FROM video_games
        WHERE Year_of_Release IS NOT NULL
        GROUP BY Genre, Year_of_Release
),
GenrePeakYear AS (
    SELECT
        Genre,
        Year_of_Release,
        Total_Global_Sales,
        RANK() OVER (PARTITION BY Genre ORDER BY Total_Global_Sales DESC) AS SalesRank
    FROM GenereYearSales
)
SELECT
    Year_of_Release,
    COUNT(DISTINCT Genre) as Num_Genres_At_Peak
FROM GenrePeakYear
WHERE SalesRank = 1
GROUP BY Year_of_Release
ORDER BY Num_Genres_At_Peak DESC;


--3-- 
WITH CTE_Weighted_Average AS (
SELECT 
Rating,
ROUND(SUM(critic_score*critic_count) /SUM(critic_count),1) AS  Weighted_Average
FROM video_games
WHERE Rating IS NOT NULL 
AND Critic_Score IS NOT NULL
GROUP BY Rating
),
CTE_Average AS ( 
SELECT
Rating,
ROUND(AVG(Critic_Score),1) AS Average_Critic
FROM video_games
WHERE Rating IS NOT NULL 
AND Critic_Score IS NOT NULL
GROUP BY Rating
), 
CTE_Mode AS (
SELECT 
Rating,
critic_score, 
COUNT(*) AS Count_Score,
ROW_NUMBER() OVER (PARTITION BY Rating ORDER BY COUNT(*) DESC) AS RNK 
FROM video_games
WHERE Rating IS NOT NULL 
AND Critic_Score IS NOT NULL
GROUP BY Rating,critic_score
)
SELECT 
M.Rating,
W.Weighted_Average,
Ave.Average_Critic,
M.Critic_Score AS Mode_Score
FROM CTE_Mode AS M JOIN CTE_Average AS Ave ON M.Rating=Ave.Rating JOIN CTE_Weighted_Average AS W
ON Ave.Rating=W.Rating
WHERE M.RNK = 1;



--SELECT 
--Rating,
--ROUND(SUM(critic_score*critic_count) /SUM(critic_count),1) AS  Weighted_Average
--FROM video_games
--WHERE Rating IS NOT NULL 
--AND Critic_Score IS NOT NULL
--GROUP BY Rating


--SELECT
--Rating,
--ROUND(AVG(Critic_Score),1) AS Average_Critic
--FROM video_games
--WHERE Rating IS NOT NULL 
--AND Critic_Score IS NOT NULL
--GROUP BY Rating

--SELECT 
--Rating,
--critic_score, 
--COUNT(*) AS Count_Score,
--ROW_NUMBER() OVER (PARTITION BY Rating ORDER BY COUNT(*) DESC) AS RNK 
--FROM video_games
--WHERE Rating IS NOT NULL 
--AND Critic_Score IS NOT NULL
--GROUP BY Rating,critic_score




--4--
WITH CTE_Genre AS(
SELECT DISTINCT Genre
FROM video_games
WHERE Genre IS NOT NULL
),
CTE_Platform AS(
SELECT DISTINCT Platform
FROM video_games 
WHERE Platform IS NOT NULL
),
CTE_Year_of_Release AS(
SELECT DISTINCT Year_of_Release 
FROM video_games
WHERE Year_of_Release IS NOT NULL
)
SELECT G.Genre,P.Platform,Y.Year_of_Release, ISNULL(SUM(V.Global_Sales), 0) AS Sum_Global_Sales 
FROM CTE_Genre AS G CROSS JOIN CTE_Platform AS P CROSS JOIN CTE_Year_of_Release AS Y 
LEFT JOIN video_games AS V ON V.Genre = G.Genre
AND V.Platform = P.Platform
AND V.Year_of_Release = Y.Year_of_Release
GROUP BY G.Genre,P.Platform,Y.Year_of_Release 
ORDER BY G.Genre,P.Platform,Y.Year_of_Release 



--5-- 
WITH CTE_Platforms AS(
    SELECT DISTINCT Platform
    FROM video_games 
    WHERE Platform IS NOT NULL
),
CTE_Years AS(
    SELECT DISTINCT Year_of_Release 
    FROM video_games
    WHERE Year_of_Release IS NOT NULL AND Year_of_Release < >2020
),
CTE_AllCombinations AS (
    SELECT
        p.Platform,
        y.Year_of_Release
    FROM CTE_Platforms p
    CROSS JOIN CTE_Years y
),
PlatformYearSales AS (
    SELECT
        ac.Platform,
        ac.Year_of_Release,
        ISNULL(SUM(vg.Global_Sales),0) AS Total_Global_Sales
    FROM CTE_AllCombinations AS ac
    LEFT JOIN video_games vg
        ON ac.Platform = vg.Platform
        AND ac.Year_of_Release = vg.Year_of_Release
    GROUP BY ac.Platform, ac.Year_of_Release
),
PlatformYoY AS (
    SELECT 
        Platform,
        Year_of_Release,
        Total_Global_Sales,
        LAG(Total_Global_Sales) OVER (PARTITION BY Platform ORDER BY Year_of_Release) AS Prev_Year_Sales
    FROM PlatformYearSales
),
PlatformYoY_Calc AS (
    SELECT 
        Platform,
        Year_of_Release,
        Total_Global_Sales,
        Prev_Year_Sales,
        CASE
            WHEN Prev_Year_Sales = 0 OR Prev_Year_Sales IS NULL THEN NULL
            ELSE (Total_Global_Sales - Prev_Year_Sales) / Prev_Year_Sales
        END AS YoY_Growth_Percent
    FROM PlatformYoY
),
PlatformMaxYoY AS (
    SELECT 
        Platform,
        Year_of_Release,
        YoY_Growth_Percent,
        RANK() OVER (PARTITION BY Platform ORDER BY YoY_Growth_Percent DESC) AS YoY_Rank
    FROM PlatformYoY_Calc
    WHERE YoY_Growth_Percent IS NOT NULL
)

SELECT Platform, Year_of_Release AS Peak_Year, YoY_Growth_Percent
FROM PlatformMaxYoY
WHERE YoY_Rank = 1
ORDER BY YoY_Growth_Percent DESC;




