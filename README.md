# PAN Card Validation System
![PAN](PAN.jpg)


### SQL-Based Data Integrity & Pattern Recognition Framework

![MySQL](https://img.shields.io/badge/mysql-%2300f.svg?style=for-the-badge&logo=mysql&logoColor=white) ![Data Quality](https://img.shields.io/badge/Data%20Quality-Verified-green?style=for-the-badge) ![Status](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge)

## 📋 Project Overview
In the Indian financial ecosystem, the **Permanent Account Number (PAN)** is a critical identifier. However, databases are often plagued with "dummy" or "lazy" entries (e.g., `ABCDE1234F`, `AAAAA0000A`) that pass standard length checks but are actually invalid.

This repository hosts a robust **SQL-based validation system** designed to sanitize, validate, and categorize PAN data. Unlike simple Regex checks, this system employs **advanced heuristic analysis** using custom Stored Functions to detect patterns indicative of fake data (such as sequential or repetitive characters).

---

## 🚀 Key Features
* **Automated ETL:** Bulk data loading from CSV with handling for header skipping and line termination.
* **Data Sanitization:** Automatic trimming of whitespace, case normalization (Upper Case), and duplicate detection.
* **Advanced Heuristics (Custom Functions):**
    * **Repetitive Character Detection:** Identifies lazy entries (e.g., `AAAAA`) using a custom loop function.
    * **Sequential Pattern Detection:** Identifies sequential inputs (e.g., `ABCDE`, `1234`) using ASCII value comparison.
* **Regex Validation:** Enforces the standard government format: `5 Letters` + `4 Digits` + `1 Letter`.
* **Reporting View:** A unified view categorizing all records as `Valid` or `Invalid`.

---


## 📂 File Structure
```text
├── PAN_Validation_Script.sql   # Main Logic (DDL, DML, Functions)
├── Dataset.xlsx # Sample Dataset
├── Problem_Statement.pdf
└── README.md                   # Project Documentation
```

---

## 🗂️ Schema Setup

```sql
DROP TABLE IF EXISTS PAN_VALIDATION;

CREATE TABLE PAN_VALIDATION (
    PAN_NUMBER VARCHAR(20)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PAN Number Validation Dataset.csv'
INTO TABLE PAN_VALIDATION
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
```

---

## 🛡️ Error Handling

### ✅ Verify Data Load
Ensure that the data has been successfully inserted:
```sql
SELECT COUNT(*) AS loaded_records 
FROM PAN_VALIDATION;
```

### ✔️ Commit Changes  
If the record count is correct and the data load is successful:
```sql
COMMIT;
```

### ❌ Rollback on Failure  
If any issues or inconsistencies are detected:
```sql
ROLLBACK;
```

## 🛠️ Technical Architecture

### 1. Data Cleaning Pipeline
Before validation, the raw data undergoes a rigorous cleaning process to identify anomalies (Nulls, Duplicates, Formatting issues) and standardize the input.

```sql
-- 1. Identify missing data
SELECT * FROM PAN_VALIDATION WHERE PAN_NUMBER IS NULL;

-- 2. Check for duplicates
SELECT PAN_NUMBER, count(*) FROM PAN_VALIDATION 
GROUP BY PAN_NUMBER HAVING count(*) > 1;

-- 3. Identify leading/trailing spaces
SELECT * FROM PAN_VALIDATION WHERE PAN_NUMBER <> TRIM(PAN_NUMBER);

-- 4. Identify Case Sensitivity issues (Lowercase/Mixed case)
SELECT * FROM PAN_VALIDATION WHERE BINARY PAN_NUMBER <> UPPER(PAN_NUMBER); 

-- 5. Final Standardization (Used in Logic CTE)
SELECT DISTINCT UPPER(TRIM(PAN_NUMBER)) As Cleaned_PAN
FROM PAN_VALIDATION 
WHERE PAN_NUMBER IS NOT NULL 
AND TRIM(PAN_NUMBER) <> '';
```

### 2. The Logic Core (Stored Functions)
The system uses two deterministic functions to catch "fake" data that follows the correct length but fails logic tests.

| Function Name | Purpose | Logic |
| :--- | :--- | :--- |
| `Check_adjacent_Char` | Detects repeating adjacent characters. | Iterates through substrings; returns flag if `char[i] == char[i+1]`. |
| `Check_sequential_Char` | Detects sequential alphabets or numbers. | Compares ASCII values to check if the difference is exactly 1. |

**Function 1: Check Adjacent Characters**
```sql
DELIMITER $$
CREATE FUNCTION Check_Adjacent_Char(input_str VARCHAR(20))
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
```

**Function 2: Check Sequential Characters**
```sql
DELIMITER $$
CREATE FUNCTION Check_Sequential_Char(input_str VARCHAR(20))
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
```

### 3. Validation & Categorization
The final validation relies on a **Common Table Expression (CTE)** workflow inside a View. This combines the Regex pattern check with the custom Heuristic functions.

<details>
<summary><strong>🔍 Click to View The Validation Logic (CTE & JOIN)</strong></summary>

```sql
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
        WHERE Check_Adjacent_Char(PAN_NUMBER) = 0
        AND Check_Sequential_Char(SUBSTRING(PAN_NUMBER,1,5)) = 0
        AND Check_sequential_Char(SUBSTRING(PAN_NUMBER,6,4)) = 0
        AND REGEXP_LIKE(PAN_NUMBER,'^[A-Z]{5}[0-9]{4}[A-Z]$')
    )
SELECT
    ccp.PAN_NUMBER,
    CASE WHEN cvp.PAN_NUMBER IS NOT NULL THEN 'Valid PAN'
         ELSE 'Invalid PAN'
    END Category
FROM
Cte_Cleaned_PAN ccp LEFT JOIN Cte_Validated_PAN cvp 
ON ccp.PAN_NUMBER = cvp.PAN_NUMBER
);
```
</details>

---


## 📊 Performance & Insights
The script concludes with a **Summary Table** providing immediate insights into the dataset quality:

| Metric | Description |
| :--- | :--- |
| **Total_PAN_Processed** | Total raw rows ingested. |
| **Total_Valid_PAN** | Records passing Regex AND Heuristic checks. |
| **Total_Invalid_PAN** | Records failing pattern or heuristic checks. |
| **Total_Blank_PAN** | Null or empty entries removed during processing. |

---

## 🧠 Why This Matters
Data quality is the foundation of analytics. In a real-world fintech scenario, invalid PAN cards can lead to:
* KYC failures.
* Regulatory compliance penalties.
* Inaccurate user demographic analysis.

This project demonstrates how to push logic **upstream to the database layer**, ensuring that only clean, validated data reaches the application or analytics layer.

---


## 💻 Installation & Usage

**Prerequisites:** MySQL Server 8.0+

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/sonukc9370-ai/PAN-Card-Validation-System
    ```
2.  **Prepare the Data**
    Ensure your CSV file is located in the MySQL `Uploads` directory (or update the path in the script).
    
4.  **Run the Script**
    Execute the `pan_validation.sql` file in your SQL Workbench or CLI.

---
