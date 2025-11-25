DROP TABLE IF EXISTS PAN_VALIDATION;
CREATE TABLE PAN_VALIDATION(
	PAN_NUMBER VARCHAR(20)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PAN Number Validation Dataset.csv'
INTO TABLE PAN_VALIDATION
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- Identify missing data:
SELECT * FROM PAN_VALIDATION WHERE PAN_NUMBER IS NULL;

-- Checking for the duplicates
SELECT PAN_NUMBER,count(*) FROM PAN_VALIDATION 
GROUP BY PAN_NUMBER HAVING count(*)>1;

-- Checking for leading/trailing spaces
SELECT * FROM PAN_VALIDATION WHERE PAN_NUMBER <> TRIM(PAN_NUMBER);

-- Checking for Cases
SELECT * FROM PAN_VALIDATION WHERE BINARY PAN_NUMBER <> UPPER(PAN_NUMBER); 

-- Cleaned PAN Numbers
SELECT DISTINCT UPPER(TRIM(PAN_NUMBER)) As Cleaned_PAN
FROM PAN_VALIDATION WHERE PAN_NUMBER IS NOT NULL 
AND TRIM(PAN_NUMBER) <> '';


-- Function to Check if adjacent characters are present in a string
DELIMITER $$
CREATE FUNCTION Check_adjacent_Char(input_str VARCHAR(20))
RETURNS TINYINT
DETERMINISTIC
BEGIN
	DECLARE i INT DEFAULT 1;
    DECLARE first5 VARCHAR(5);
    DECLARE results TINYINT(1) DEFAULT 0;
    
    Set first5 = SUBSTRING(input_str,1,5);
    My_loop: LOOP
		IF i >= 5 THEN
			LEAVE My_loop;
		END IF;
        
        IF SUBSTRING(first5,i,1)=SUBSTRING(first5,i+1,1) THEN
			Set results = 1;
            LEAVE My_loop;
		END if;
        
        Set i=i+1;
    
	END LOOP My_loop;
    RETURN results;
    
END $$
DELIMITER ;
-- Function to check for the sequential characters in a string
 DELIMITER $$
CREATE FUNCTION Check_sequential_Char(input_str VARCHAR(20))
RETURNS TINYINT
DETERMINISTIC
BEGIN
	DECLARE i INT DEFAULT 1;
    DECLARE str_length INTEGER;
    DECLARE result TINYINT(1) DEFAULT 1;
    
    Set str_length = LENGTH(input_str);
    My_loop: LOOP
		IF i >= Str_length THEN 
			LEAVE My_loop;
		END IF;
        
        IF ASCII(SUBSTRING(input_str,i+1,1)) - ASCII(SUBSTRING(input_str,i,1)) <> 1 THEN
			Set result = 0;
            Leave My_loop;
		END IF;
        
        Set i=i+1;
			
    END LOOP My_loop;
    RETURN result;
END $$
DELIMITER ;

-- Regular Expression to match the PAN Pattern
SELECT * FROM PAN_VALIDATION
WHERE REGEXP_LIKE(PAN_NUMBER,'^[A-Z]{5}[0-9]{4}[A-Z]$');

-- Valid And Invalid PAN Categorization
CREATE VIEW valid_invalid_PAN As (
WITH 
	Cte_Cleaned_PAN AS (
		SELECT DISTINCT UPPER(TRIM(PAN_NUMBER)) As PAN_NUMBER
		FROM PAN_VALIDATION WHERE PAN_NUMBER IS NOT NULL 
		AND TRIM(PAN_NUMBER) <> ''
	),
    Cte_Validated_Pan As (
		SELECT *
		FROM Cte_Cleaned_PAN
		WHERE Check_adjacent_Char(PAN_NUMBER) = 0
		AND Check_sequential_Char(SUBSTRING(PAN_NUMBER,1,5)) = 0
		AND Check_sequential_Char(SUBSTRING(PAN_NUMBER,6,4)) = 0
		AND REGEXP_LIKE(PAN_NUMBER,'^[A-Z]{5}[0-9]{4}[A-Z]$')
    )
SELECT
	ccp.PAN_NUMBER,
    CASE WHEN cvp.PAN_NUMBER IS NULL THEN 'Valid PAN'
		 ELSE 'Invalid PAN'
	END Category
FROM
Cte_Cleaned_PAN ccp LEFT JOIN Cte_Validated_PAN cvp 
ON ccp.PAN_NUMBER = cvp.PAN_NUMBER
);

-- SUMMARY TABLE
WITH Cte As (SELECT 
	(SELECT COUNT(*) FROM PAN_VALIDATION) As Total_PAN_Processed,
	COUNT(CASE WHEN Category='Valid PAN' THEN 1 END) AS Total_Valid_PAN,
    COUNT(CASE WHEN Category='Invalid PAN' THEN 1 END) AS Total_Invalid_PAN
FROM 
valid_invalid_PAN
)
SELECT
	Total_PAN_Processed,
    Total_Valid_PAN,
	Total_Invalid_PAN,
    (Total_PAN_Processed- (Total_Valid_PAN + Total_Invalid_PAN)) As Total_Blank_PAN
FROM Cte;