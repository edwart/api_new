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
select bookings.*
from bookings
     LEFT JOIN xbookings ON bookings.oa_booking_no = xbookings.xoa_booking_no
     LEFT JOIN slclient  ON bookings.oa_cust_code = slclient.cu_cust_code
WHERE oa_booking_no = <% params.bookingNo %>

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
<%- IF modifiers.exists( 'orderby' ) -%>
ORDER BY <% modifiers.orderby.keys.join(',') %>
<% END %>

[GetBookings]
SELECT <% IF modifiers.exists( 'fields') %>
        <% modifiers.fields.join(',') %>
        <% ELSE %>
        *
        <% END %>
FROM bookings
     LEFT JOIN xbookings ON bookings.oa_booking_no = xbookings.xoa_booking_no
     LEFT JOIN slclient  ON bookings.oa_cust_code = slclient.cu_cust_code
WHERE bookings.oa_cand_no = <% params.candId %>
<%- IF  modifiers.exists( 'where') %>
AND <% modifiers.where.join(" AND ") %>
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
<%- IF  modifiers.exists( 'where') %>
AND <% modifiers.where.join(" AND ") %>
<% END -%>
<%- IF modifiers.exists( 'orderby' ) -%>
ORDER BY <% modifiers.orderby.keys.join(',') %>
<% END %>

[GetTimesheetById]
SELECT <%- IF modifiers.exists( 'fields') -%>
        <%- modifiers.fields.keys.join(',') -%>
        <%- ELSE -%>
        timepool.*,slclient.cu_name,bookings.oa_assignment, cands.* 
        <%- END %>
FROM timepool, bookings, slclient, cands
WHERE tp_timesheet_no = <% params.timesheetNo %>
AND bookings.oa_booking_no = timepool.tp_booking_no
AND bookings.oa_cust_code = slclient.cu_cust_code
AND cands.cand_cand_no = bookings.oa_cand_no

[GetTimesheet]
SELECT <%- IF modifiers.exists( 'fields') -%>
        <%- modifiers.fields.keys.join(',') -%>311G
        <%- ELSE -%>
        timepool.*,<% FOREACH n IN [1, 2, 3, 4, 5, 6, 7, 8] %>bookings.oa_rate_hours__<% n %><% IF n < 8 %>,<% END %><%END %>
        <%- END %>
FROM timepool, bookings
WHERE tp_booking_no = <% params.bookingNo %>
AND bookings.oa_booking_no = <% params.bookingNo %>
AND tp_week_date = <% params.weekendDate %>

[UpdateTimesheet]
UPDATE timepool
SET <%- FOREACH param IN params.keys.sort -%><% param %> = <% params.$param %><% UNLESS loop.last %>, <% END %>
<% END %>
WHERE tp_timesheet_no = <% params.tp_timesheet_no %>

[NewTimesheet]
INSERT INTO timepool (
<% params.keys.sort.join(",\n") %>
)
VALUES
(
<% FOREACH param IN params.keys.sort -%>
    <% params.$param %><% UNLESS loop.last %>,<% END %>
<% END -%>
)

[HIDENGetPendingTimesheets]
SELECT oa_booking_no,
       oa_cand_no
       oa_assignment,
       oa_extranet
FROM bookings
LEFT JOIN xbookings ON bookings.oa_booking_no = xbookings.xoa_booking_no
WHERE oa_status = "Live"
AND oa_extranet IN('p','y')
AND oa_date_start <= CURDATE()
AND (oa_date_end = NULL or oa_date_end >= CURDATE())

[GetBlankTimesheets]
SELECT tp_timesheet_no, tp_week_date
FROM timepool, bookings
WHERE timepool.tp_booking_no = bookings.oa_booking_no
AND bookings.oa_cand_no = <% params.candId %>
AND timepool.tp_extranet_status = '' 
<%- IF  params.exists( 'bookingNo') %>
AND bookings.oa_booking_no = <% params.bookingNo %>
<% END -%>
<%- IF  modifiers.exists( 'where') %>
<% modifiers.where.join(" AND ") %>
<% END -%>
<%- IF  modifiers.exists( 'search') %>
<% modifiers.search.join(" AND ") %>
<% END -%>


[GetTimesheetHistory]
SELECT <%- IF modifiers.exists( 'fields') -%>
        <%- modifiers.fields.join(',') -%>
        <%- ELSE -%>
        bookings.oa_booking_no, bookings.oa_assignment, slclient.cu_name, tp_timesheet_no, tp_extranet_status, tp_week_date, tp_week_no, tp_json_entry, tp_hours_tot, tp_extranet_queried, tp_extranet_query_type, tp_extranet_query_reason, tp_not_working, tp_comment
        <%- END %>
FROM timepool, bookings
     LEFT JOIN xbookings ON bookings.oa_booking_no = xbookings.xoa_booking_no
     LEFT JOIN slclient  ON bookings.oa_cust_code = slclient.cu_cust_code
WHERE timepool.tp_booking_no = bookings.oa_booking_no
AND bookings.oa_cand_no = <% params.candId %>
AND timepool.tp_extranet_status in ('Paid', 'Submitted', 'Approved', 'Entered')
<%- IF  params.exists( 'bookingNo') %>
AND timepool.tp_booking_no = <% params.bookingNo %>
<% END -%>

<%- IF  modifiers.exists( 'where') %>
<% modifiers.where.join(" AND ") %>
<% END -%>
<%- IF  modifiers.exists( 'search') %>
<% modifiers.search.join(" AND ") %>
<% END -%>
<%- IF modifiers.exists( 'orderby' ) %>
ORDER BY <% modifiers.orderby.join(',') %>
<% END %>
