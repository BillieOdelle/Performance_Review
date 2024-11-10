/* Data date range is Feb 2023 to August 2024.  Days opened to current day will be high as no activitiy has been obtained since August 2024 */

--Joining all tables together

Select * FROM sc_req_items i
	LEFT JOIN sc_task t ON t.request = i.number
	LEFT JOIN sc_req_supplement s ON s.number = i.number
	LEFT JOIN task_sla ts ON ts.request_number = i.number

--Cleansing data into one table
SELECT
	i.number as request_number,
	i.assignment_group as Department1,
	i.sys_created_on as opened_date,
	i.closed_at as Request_Closed,
	i.state as request_state,
	t.number as Task_number,
	t.status as Task_status,
	t.assignment_group as Department2,
	t.closed_at as Task_Closed,
	t.approval as Approval_status,
	CASE
		WHEN csr_triggered = 'FALSE' AND ohs_triggered = 'FALSE' THEN 'Low Risk'
		WHEN csr_triggered = 'FALSE' AND ohs_triggered = 'TRUE' THEN 'Medium Risk'
		WHEN csr_triggered = 'TRUE' AND ohs_triggered = 'FALSE' THEN 'Medium Risk'
		ELSE 'High Risk'
		END AS Complexity_Risk
FROM sc_req_items i
	LEFT JOIN sc_task t ON t.request = i.number
	LEFT JOIN sc_req_supplement s ON s.number = i.number
	LEFT JOIN task_sla ts ON ts.request_number = i.number

--Create table with cleaned data

Create table performance_review (
	request_number VARCHAR(50),
	department1 VARCHAR(250),
	opened_date DATE,
	request_closed DATE,
	request_state VARCHAR(250),
	task_number VARCHAR(50),
	department2 VARCHAR(250),
	task_status VARCHAR(250),
	task_closed DATE,
	approval_status VARCHAR(250),
	complexity_risk text
);

--Generating full table

SELECT * FROM performance_review

SELECT
	request_state,
	task_status
FROM performance_review
GROUP BY
request_state, task_status

--count totals

SELECT
    COUNT(DISTINCT request_number) AS Total_requests,
	COUNT(DISTINCT CASE WHEN request_state IN ('Pending', 'Awaiting Customer Info', 'Work in Progress', 'Awaiting Call Closure', 'Open') THEN request_number END) AS Req_open,
    COUNT(DISTINCT CASE WHEN request_state IN ('Closed Complete', 'Closed Incomplete', 'Closed Skipped') THEN request_number END) AS Req_complete,
    ROUND(
        COUNT(DISTINCT CASE WHEN request_state IN ('Closed Complete', 'Closed Incomplete', 'Closed Skipped') THEN request_number END)::decimal 
        / COUNT(DISTINCT request_number) * 100, 2
    ) AS Closed_Requests_Percentage,
    COUNT(task_number) AS Total_tasks,
	COUNT(DISTINCT CASE WHEN request_state IN ('Waiting for customer information', 'Waiting for Other', 'Open') THEN request_number END) AS task_open,
    COUNT(DISTINCT CASE WHEN task_status = 'Closed Complete' THEN task_number END) AS Task_complete,
    ROUND(
        COUNT(DISTINCT CASE WHEN task_status = 'Closed Complete' THEN task_number END)::decimal 
        / NULLIF(COUNT(DISTINCT task_number), 0) * 100, 2
    ) AS Closed_Subtask_Percentage,
    COUNT(CASE WHEN complexity_risk = 'Low Risk' THEN 1 END) AS Low_Risk,
    COUNT(CASE WHEN complexity_risk = 'Medium Risk' THEN 1 END) AS Medium_Risk,
    COUNT(CASE WHEN complexity_risk = 'High Risk' THEN 1 END) AS High_Risk,
    COUNT(CASE WHEN approval_status = 'Approved' THEN 1 END) AS Approved,
    COUNT(CASE WHEN approval_status = 'Rejected' THEN 1 END) AS Rejected
FROM performance_review;

--Total by assignment group

--department 1

SELECT
	department1,
	COUNT(*) as total_requests,
	COUNT(CASE WHEN complexity_risk = 'Low Risk' THEN 1 END) AS Low_Risk,
    COUNT(CASE WHEN complexity_risk = 'Medium Risk' THEN 1 END) AS Medium_Risk,
    COUNT(CASE WHEN complexity_risk = 'High Risk' THEN 1 END) AS High_Risk,
    COUNT(CASE WHEN approval_status = 'Approved' THEN 1 END) AS Approved,
    COUNT(CASE WHEN approval_status = 'Rejected' THEN 1 END) AS Rejected
FROM performance_review
GROUP BY department1 
ORDER BY department1 Asc


-- department 2
/*  There is a one to many relationship between request_number and task_number.  task_number is created when a request has a risk assessment requirement */

SELECT
	department2,
	COUNT(*) as total_requests,
	COUNT(CASE WHEN complexity_risk = 'Low Risk' THEN 1 END) AS Low_Risk,
    COUNT(CASE WHEN complexity_risk = 'Medium Risk' THEN 1 END) AS Medium_Risk,
    COUNT(CASE WHEN complexity_risk = 'High Risk' THEN 1 END) AS High_Risk,
    COUNT(CASE WHEN approval_status = 'Approved' THEN 1 END) AS Approved,
    COUNT(CASE WHEN approval_status = 'Rejected' THEN 1 END) AS Rejected
FROM performance_review
WHERE department2 is not null
GROUP BY department2
ORDER BY department2 Asc


--turnaround time - dates between opened day to closed date (this does not include weekends)

--requests

WITH request_turnaround AS (
    SELECT 
        request_number,
        opened_date,
        request_closed,
        opened_date + generate_series(0, (request_closed - opened_date)) AS day
    FROM 
        performance_review
)

SELECT 
    request_number,
    opened_date,
    request_closed,
    COUNT(*) AS turnaround_days  -- Count of weekdays between dates
FROM 
    DateRange
WHERE 
    EXTRACT(DOW FROM day) NOT IN (0, 6)  -- Exclude Sundays (0) and Saturdays (6)
GROUP BY 
    request_number, opened_date, request_closed;
	
--subtasks

WITH task_turnaround AS (
    SELECT 
        task_number,
        opened_date,
        task_closed,
        opened_date + generate_series(0, (task_closed - opened_date)) AS day
    FROM 
        performance_review
)

SELECT 
    task_number,
    opened_date,
    task_closed,
    COUNT(*) AS turnaround_days  -- Count of weekdays between dates
FROM 
    task_turnaround
WHERE 
    EXTRACT(DOW FROM day) NOT IN (0, 6)  -- Exclude Sundays (0) and Saturdays (6)
GROUP BY 
    task_number, opened_date, task_closed;
	
--requests open by department and how long a request has been opened for

SELECT
	department1,
    COUNT(DISTINCT request_number) AS Total_requests,
	COUNT(DISTINCT CASE WHEN request_state IN ('Pending', 'Awaiting Customer Info', 'Work in Progress', 'Awaiting Call Closure', 'Open') 
		  THEN request_number END) AS Req_open
FROM performance_review
GROUP BY department1

--tasks open by department and how long a request has been opened for

SELECT
	department2,
    COUNT(DISTINCT task_number) AS Total_requests,
	COUNT(DISTINCT CASE WHEN task_status IN ('Waiting for customer information', 'Waiting for Other', 'Open') 
		  THEN task_number END) AS task_open
FROM performance_review
WHERE department2 is not null
GROUP BY department2

--table by requests open and how long they have been opened for from creation date, to today's date

SELECT 
    DISTINCT request_number,
    opened_date,
    (
        SELECT COUNT(*)
        FROM generate_series(opened_date, CURRENT_DATE, INTERVAL '1 day') AS series(day)
        WHERE EXTRACT(DOW FROM series.day) NOT IN (0, 6)  -- Exclude Sundays (0) and Saturdays (6)
    ) AS days_from_opened_to_today
FROM 
    performance_review
ORDER BY opened_date ASC

--table by tasks open and how long they have been opened for from creation date, to today's date

SELECT 
    DISTINCT task_number,
    opened_date,
    (
        SELECT COUNT(*)
        FROM generate_series(opened_date, CURRENT_DATE, INTERVAL '1 day') AS series(day)
        WHERE EXTRACT(DOW FROM series.day) NOT IN (0, 6)  -- Exclude Sundays (0) and Saturdays (6)
    ) AS days_from_opened_to_today
FROM 
    performance_review
WHERE task_number is not null
ORDER BY opened_date ASC






