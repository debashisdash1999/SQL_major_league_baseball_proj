USE major_league_baseball;

-- PART-1: SCHOOL ANALYSIS

-- (i) View schools and school_details tables
SELECT * FROM schools;
SELECT * FROM school_details;

-- (ii) In each decade, how many schools were there that produced players?
SELECT FLOOR(yearID / 10) * 10 AS decade,
       COUNT(DISTINCT schoolID) AS num_of_schools
FROM schools
GROUP BY decade
ORDER BY decade;

-- (iii) Top 5 schools that produced most players
SELECT sd.name_full AS school_name, COUNT(DISTINCT s.playerID) AS num_of_players
FROM schools s LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY s.schoolID
ORDER BY num_of_players DESC
LIMIT 5;

-- (iv) For each decade, what were the names of the top 3 schools that produced the most players?
WITH ds AS (SELECT FLOOR(s.yearID / 10) * 10 AS decade, sd.name_full AS school_name, COUNT(DISTINCT s.playerID) AS num_of_players
						FROM schools s LEFT JOIN school_details sd
						ON s.schoolID = sd.schoolID
						GROUP BY decade ,s.schoolID),
	 rn AS (SELECT decade, school_name, num_of_players,
           ROW_NUMBER() OVER (PARTITION BY decade ORDER BY num_of_players DESC) AS row_num
           FROM ds)
           
SELECT * FROM rn 
WHERE row_num <= 3
ORDER BY decade DESC, row_num;

-- PART-2: SALARY ANALYSIS

-- (i) View the salaries table
SELECT * FROM salaries;

-- (ii) Return the top 20% of teams in terms of average annual spending
WITH ts AS (SELECT teamID, yearID, SUM(salary) AS total_spend
			FROM salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID),
            
		sp AS (SELECT teamID, AVG(total_spend) AS avg_spend,
			   NTILE(5) OVER (ORDER BY AVG(total_spend) DESC) AS spend_pct
			   FROM ts
			   GROUP BY teamID)
SELECT teamID, ROUND(avg_spend / 1000000, 1) AS avg_spend_in_millions
FROM sp WHERE spend_pct = 1;

-- (iii) For each team, show the cumulative sum of spending over the years
WITH ts AS (SELECT teamID, yearID, SUM(salary) AS total_spend
            FROM salaries
            GROUP BY teamID, yearID
            ORDER BY teamID, yearID)
            
SELECT teamID, yearID,
       ROUND(SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID) / 1000000, 1) AS cumulative_sum_in_mil
FROM ts;

-- (iv) Return the first year that each team's cumulative spending surpassed 1 billion
WITH ts AS (SELECT teamID, yearID, SUM(salary) AS total_spend
            FROM salaries
            GROUP BY teamID, yearID
            ORDER BY teamID, yearID),
            
     cs AS (SELECT teamID, yearID,
		    SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID) AS cumulative_sum
	        FROM ts),
	 
     rn AS (SELECT teamID, yearID, cumulative_sum,
            ROW_NUMBER() OVER (PARTITION BY teamID ORDER BY cumulative_sum) AS rn
            FROM cs
            WHERE cumulative_sum > 1000000000)
SELECT teamID, yearID, ROUND(cumulative_sum / 1000000000, 2) AS cum_sum_in_bil 
FROM rn WHERE rn = 1;

-- PART-3: PLAYER CAREER ANALYSIS

-- (i) View the players table and find the number of players on the field
SELECT * FROM players;
SELECT COUNT(*) FROM players;

-- (ii) For each player, calculate age at debut, age at last game, and career length(all in yrs). Sort fron longest to shortest career.
SELECT nameGiven, debut, finalGame,
       CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birthdate,
       TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE), debut) AS starting_age,
	   TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE), finalGame) AS ending_age,
	   TIMESTAMPDIFF(YEAR, debut, finalGame) AS career_length_in_yrs
FROM players;
-- for our output
SELECT nameGiven, 
	   TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE), debut) AS starting_age,
	   TIMESTAMPDIFF(YEAR, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE), finalGame) AS ending_age,
	   TIMESTAMPDIFF(YEAR, debut, finalGame) AS career_length_in_yrs
FROM players
ORDER BY career_length_in_yrs DESC;

-- (iii) What team did each player play on for their starting and ending yrs?
SELECT p.playerID, p.nameGiven, p.debut, p.finalGame, s.yearID AS starting_yr, s.teamID AS initial_team, 
       e.yearID AS end_yr, e.teamID AS last_team
FROM players p 
INNER JOIN salaries s
ON p.playerID = s.playerID AND YEAR(p.debut) = s.yearID
INNER JOIN salaries e
ON p.playerID = e.playerID AND YEAR(p.finalGame) = e.yearID;

-- (iv) How many players started and ended on the same team and also played for over a decade?
SELECT p.playerID, p.nameGiven, p.debut, p.finalGame, s.yearID AS starting_yr, s.teamID AS initial_team, 
       e.yearID AS end_yr, e.teamID AS last_team
FROM players p 
INNER JOIN salaries s
ON p.playerID = s.playerID AND YEAR(p.debut) = s.yearID
INNER JOIN salaries e
ON p.playerID = e.playerID AND YEAR(p.finalGame) = e.yearID
WHERE s.teamID = e.teamID AND e.yearID - s.yearID >= 10;

-- PART-4: PLAYER COMPARISION ANALYSIS

-- (i) View players table
SELECT * FROM players;

-- (ii) Which players have the same birthday?
WITH bn AS (SELECT CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birthdate, nameGiven
            FROM players)
SELECT birthdate, GROUP_CONCAT(nameGiven SEPARATOR ', ') AS list_of_players
FROM bn
WHERE birthdate IS NOT NULL
GROUP BY birthdate
ORDER BY birthdate;

-- (iii) Create a summary table that shows for each team, what percent of players bat right, left and both.
SELECT * FROM players;

SELECT playerID, bats
FROM players;

SELECT DISTINCT (bats) FROM players;

SELECT * FROM salaries;

SELECT	s.teamID,
		ROUND(SUM(CASE WHEN p.bats = 'R' THEN 1 ELSE 0 END) / COUNT(s.playerID) * 100, 1) AS bats_right,
        ROUND(SUM(CASE WHEN p.bats = 'L' THEN 1 ELSE 0 END) / COUNT(s.playerID) * 100, 1) AS bats_left,
        ROUND(SUM(CASE WHEN p.bats = 'B' THEN 1 ELSE 0 END) / COUNT(s.playerID) * 100, 1) AS bats_both
FROM	salaries s LEFT JOIN players p
		ON s.playerID = p.playerID
GROUP BY s.teamID;

-- (iv) How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
WITH hw AS (SELECT	FLOOR(YEAR(debut) / 10) * 10 AS decade,
			AVG(height) AS avg_height, AVG(weight) AS avg_weight
			FROM players
			GROUP BY decade)
            
SELECT decade,
	   avg_height - LAG(avg_height) OVER(ORDER BY decade) AS height_diff,
	   avg_weight - LAG(avg_weight) OVER(ORDER BY decade) AS weight_diff
FROM hw
WHERE decade IS NOT NULL;



