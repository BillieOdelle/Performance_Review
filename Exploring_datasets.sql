/*

Exploring data.

Counting number of tickets over all, by team, by risk rating and identifying how many days a ticket may be open.

Definition of request Complexity:
Low = No CSR or OH&S task
Medium = Triggered with CSR or OH&S task
High = Triggered both a CSR or OH&S
*/

--Available tables
SELECT * FROM sc_req_items -- all requests, first level department
SELECT * FROM sc_task -- combination of opened, closed, waiting for customer information or waiting for other information
SELECT * FROM task_sla -- completed requests
SELECT * FROM sc_req_supplement -- Requests with request_type and sector allocations

--Total number of requests received by table

/* 2056 requests, 1579 subtasks, 293 task_sla, 611 sc_req_supplement */

SELECT COUNT(*) FROM sc_req_items
SELECT COUNT(*) FROM sc_task
SELECT COUNT(*) FROM task_sla
SELECT COUNT(*) FROM sc_req_supplement

/*
1. Total number of requests/tasks received 
2. Total number of requests/tasks completed 
3. Percentage of requests/tasks completed 
4. Total number of requests received by Complexity

*/
WITH tot_completed AS (
    SELECT 
        COUNT(*) AS Total_Count,
        COUNT(CASE WHEN state = 'Closed Incomplete' THEN 1 END) AS Closed_Incomplete,
        COUNT(CASE WHEN state = 'Closed Skipped' THEN 1 END) AS Closed_Skipped,
        COUNT(CASE WHEN state = 'Closed Complete' THEN 1 END) AS Closed_Complete,
        COUNT(CASE WHEN csr_triggered = 'TRUE' AND ohs_triggered = 'TRUE' THEN 1 END) AS High_risk,
        COUNT(CASE WHEN csr_triggered = 'TRUE' AND ohs_triggered = 'FALSE' THEN 1 END) AS Medium_risk_CSR,
        COUNT(CASE WHEN csr_triggered = 'FALSE' AND ohs_triggered = 'TRUE' THEN 1 END) AS Medium_risk_OHS,
        COUNT(CASE WHEN csr_triggered = 'FALSE' AND ohs_triggered = 'FALSE' THEN 1 END) AS Low_risk
    FROM sc_req_items
),
task_summary AS (
    SELECT 
        COUNT(*) AS Total_Count,
        COUNT(CASE WHEN state = 'Open' THEN 1 END) AS Open_tickets,
        COUNT(CASE WHEN state = 'Waiting for Other' THEN 1 END) AS Waiting_Info,
        COUNT(CASE WHEN state = 'Waiting for customer information' THEN 1 END) AS Waiting_Customer_Info,
        COUNT(CASE WHEN state = 'Closed Complete' THEN 1 END) AS Closed_Complete,
        ROUND(COUNT(CASE WHEN state = 'Closed Complete' THEN 1 END)::decimal / COUNT(*) * 100, 2) AS Task_Percentage
    FROM sc_task
)

SELECT 
    tc.Total_Count AS Total_Requests,
    (tc.Closed_Incomplete + tc.Closed_Skipped + tc.Closed_Complete) AS Total_Closed,
    ROUND(((tc.Closed_Incomplete + tc.Closed_Skipped + tc.Closed_Complete)::decimal / tc.Total_Count) * 100, 2) AS Request_Percentage,
    tc.Low_risk,
    (tc.Medium_risk_CSR + tc.Medium_risk_OHS) AS Medium_risk,
    tc.High_risk,
    ts.Total_Count AS Total_Tasks,
    ts.Closed_Complete AS Task_Closed_Complete,
    ts.Task_Percentage
FROM tot_completed AS tc
CROSS JOIN task_summary AS ts;

/* How many requests were rejected per assignment_group */
SELECT * FROM sc_task

SELECT
	assignment_group as Department,
	COUNT(*) as total_rejected
FROM sc_task
WHERE approval = 'Rejected'
Group By assignment_group


/*  Count requests opened and closed in a month */
-- Opened request 2023 by Month
SELECT 
	COUNT(*) as Total_Requests_Open,
	TO_CHAR(sys_created_on, 'FMMonth') as Open_Month,
	EXTRACT(MONTH FROM sys_created_on) AS Month_Number
FROM sc_req_items
WHERE TO_CHAR(sys_created_on, 'YYYY') = '2023'
Group By Open_Month, Month_Number
Order By Month_Number Asc
-- Opened request 2024 by Month
SELECT 
	COUNT(*) as Total_Requests_Open,
	TO_CHAR(sys_created_on, 'FMMonth') as Open_Month,
	EXTRACT(MONTH FROM sys_created_on) AS Month_Number
FROM sc_req_items
WHERE TO_CHAR(sys_created_on, 'YYYY') = '2024'
Group By Open_Month, Month_Number
Order By Month_Number Asc
-- Closed request by month and year
WITH Monthly_Count AS (
    SELECT
        TO_CHAR(closed_at, 'FMMonth') AS Closed_Month,  -- 'FM' removes padding
        TO_CHAR(closed_at, 'YYYY') AS Closed_Year,
        COUNT(number) AS Request_number,
        EXTRACT(MONTH FROM closed_at) AS Month_Number  -- Extract month number for ordering
    FROM sc_req_items
    GROUP BY Closed_Month, Closed_Year, Month_Number
)
SELECT
    Closed_Month,
    Closed_Year,
    Request_number
FROM Monthly_Count
WHERE Closed_Month IS NOT NULL AND Closed_Year IS NOT NULL
ORDER BY Closed_Year DESC, Month_Number ASC;

