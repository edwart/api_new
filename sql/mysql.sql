[list_customers]
SELECT `cu_cust_code`,
       `cu_name`
FROM slcust
WHERE `cu_cust_code` 
order by `cu_cust_code` desc 

[get_customer]
SELECT *
FROM slcust
WHERE `cu_cust_code` = ?
LIMIT 0,1;

[GetOpenJobs]
select jb_job_no
FROM job
WHERE jb_job_status = 'Open'

[GetJobDetails]
select *
FROM job
WHERE jb_job_no = [% jobNo %]
