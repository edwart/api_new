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

[UpdateJobDetails]
update job
set [% FOREACH field IN fields %]set [% field %] = [% fields.field %][% UNLESS count.last %],[% END %]i
[% END %]
WHERE jb_job_no = [% jobNo %]
 
[GetRateCodes]
select rc_payrate_no,
       rc_pay_type,
       rc_pay_tax,
       rc_pay_vatonly,
       rc_pay_factor,
       rc_pay_desc,
       rc_rate_desc,
       rc_pay_spec,
       rc_pay_rate,
       rc_inv_vattype,
       rc_inv_vatonly,
       rc_inv_factor,
       rc_inv_rate,
       rc_factor_code,
       rc_hrs_day
from ratecode

[GetBookings]
select oa_booking_no
from bookings

[GetBookingTimesheets]
select th_timesheet_no,
        th_workwkend
from timesheet
where th_booking_no = [% bookingNo %]


[GetBookingDetails]
select bookings.*,  
       timesheet.*
       s
from bookings,
    timesheet
where th_timesheet_no = oa_timesheet_no
and oa_booking_no = [% bookingNo %]
and th_paywkend = [% weekEndDate %]
