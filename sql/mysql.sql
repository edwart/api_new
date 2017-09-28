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
WHERE jb_job_no = <% jobNo %>

[UpdateJobDetails]
update job
set <% FOREACH field IN fields %>set <% field %> = <% fields.field %><% UNLESS count.last %>,<% END %>i
<% END %>
WHERE jb_job_no = <% jobNo %>
 
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

[GetBookingRateCodes]
SELECT oa_booking_no,
        oa_contractcust,
        oa_payrate_no__1,
        oa_payrate_no__2,
        oa_payrate_no__3,
        oa_payrate_no__4,
        oa_payrate_no__5,
        oa_payrate_no__6,
        oa_payrate_no__7,
        oa_payrate_no__8
FROM bookings
WHERE oa_cand_no = <% candNo %>
AND 

[GetBookingDetails]
select bookings.*,  
       timesheet.*
from bookings,
    timepool
where th_timesheet_no = oa_timesheet_no
and oa_booking_no = <% bookingNo %>
and th_paywkend = <% weekEndDate %>
AND oa_cand_no = <% candNo %>

[listcandidates]
SELECT <% IF modifiers.exists( 'fields') %>
        <% modifiers.fields.keys.join(',') %>
        <% ELSE %>
        *
        <% END %>
FROM cands
<%- IF  modifiers.exists( 'search') %>
WHERE <% modifiers.search.keys.join(" AND ") %>
<% END -%>
<%- IF modifiers.exists( 'sort' ) -%>
ORDER BY <% modifiers.sort.keys.join(',') %>
<% END %>

[GetBookings]
SELECT <% IF modifiers.exists( 'fields') %>
        <% modifiers.fields %>
        <% ELSE %>
        *
        <% END %>
FROM bookings
<%- IF  modifiers.exists( 'where') %>
WHERE <% modifiers.where.join(" AND ") %>
<% END -%>
<%- IF modifiers.exists( 'orderby' ) -%>
ORDER BY <% modifiers.orderby.join(',') %>
<% END %>

[GetBookingTimesheets]
SELECT <%- IF modifiers.exists( 'fields') -%>
        <%- modifiers.fields.keys.join(',') -%>
        <%- ELSE -%>
        *
        <%- END %>
FROM timepool
WHERE tp_booking_no = <% params.bookingNo %>
<%- IF  modifiers.exists( 'search') %>
<% modifiers.search.keys.join(" AND ") %>
<% END -%>
<%- IF modifiers.exists( 'sort' ) -%>
ORDER BY <% modifiers.sort.keys.join(',') %>
<% END %>

[GetTimesheet]
SELECT <%- IF modifiers.exists( 'fields') -%>
        <%- modifiers.fields.keys.join(',') -%>
        <%- ELSE -%>
        *
        <%- END %>
FROM timepool
WHERE tp_booking_no = <% params.bookingNo %>
AND tp_week_date = <% params.weekEndDate %>

[NewTimesheet]
/*
<% USE Dumper %>
params <% Dumper.dump( params ) %>
*/
INSERT INTO timepool (
                      tp_amend_by,
                      tp_batch_no,
                      tp_booking_no,
                      tp_booking_no_V,
                      tp_branch,
                      tp_client_code,
                      tp_client_code_V,
                      tp_cost_centre,
                      tp_custref,
                      tp_error,
                      tp_hours_tot_V,
                      tp_imago_id,
                      tp_json_accept,
                      tp_json_entry,
                      tp_not_working,
                      tp_payroll_no_V,
                      tp_process_level,
                      tp_recvd_date,
                      tp_serial_code,
                      tp_source,
                      tp_surname,
                      tp_surname_V,
                      tp_type,
                      tp_type_V,
                      tp_week_no,
                      tp_week_no_V,
                      tp_xfer_date)
VALUES
(
                      <% params.tp_amend_by %>,
                      <% params.tp_batch_no %>,
                      <% params.tp_booking_no %>,
                      <% params.tp_booking_no_V %>,
                      <% params.tp_branch %>,
                      <% params.tp_client_code %>,
                      <% params.tp_client_code_V %>,
                      <% params.tp_cost_centre %>,
                      <% params.tp_custref %>,
                      <% params.tp_error %>,
                      <% params.tp_hours_tot_V %>,
                      <% params.tp_imago_id %>,
                      <% params.tp_json_accept %>,
                      <% params.tp_json_entry %>,
                      <% params.tp_not_working %>,
                      <% params.tp_payroll_no_V %>,
                      <% params.tp_process_level %>,
                      <% params.tp_recvd_date %>,
                      <% params.tp_serial_code %>,
                      <% params.tp_source %>,
                      <% params.tp_surname %>,
                      <% params.tp_surname_V %>,
                      <% params.tp_type %>,
                      <% params.tp_type_V %>,
                      <% params.tp_week_no %>,
                      <% params.tp_week_no_V %>,
                      <% params.tp_xfer_date %>)

