%default_responses = ( 200 => { description => 'success' },
                       default => { description => 'unexpected error' },
                       );
$api = {
info => {
    version => '0.0.3 (2017-18-31)',
    contact => {
                name => 'info@talisman-recruitment.com',
            },
    termsOfService => 'http://talisman-recruitment.com/terms/',
    title => 'Beacon Talisman REST API',
    license => {
                url => 'http://talisman-recruitment.com/terms/',
                name => 'Proprietary. All rights reserved. Copyright (c) Beacon Computers, Dunstable, UK, 2016.',
            },
    description => 'API for accessing Beacon Talisman recruitment software.\n',
},
swagger => '2.0',
produces => [
        'application/json'
    ],
consumes => [
        'application/json'
    ],
basePath => '/api/v1',
host => 'localhost:5000',
schemes => [
    'http',
    'https'
    ],
paths => {
'/' => {
    get => {
        summary => 'Get Api Version Info',
        operationId => 'GetApiVersionInfo',
        responses => {
            info => {
                version => 'string',
                contact => [ { name => 'string' } ],
                title => 'string',
                description => 'string',
            },
        },
    },
},
'/openJobs' => {
    get => {
        summary => 'Get List of Open Jobs',
        operationId => 'GetOpenJobs',
        responses => {
            openjobs => [ 'job.jb_job_no' ],
        },
    },
},
'/ratecodes' => {
    get => {
        summary => 'List Talisman rate codes',
        operationId => 'GetRateCodes',
        responses => {
            ratecodes => [
                'ratecode.rc_payrate_no',
                'ratecode.rc_pay_type',
                'ratecode.rc_pay_tax',
                'ratecode.rc_pay_vatonly',
                'ratecode.rc_pay_factor',
                'ratecode.rc_pay_desc',
                'ratecode.rc_rate_desc',
                'ratecode.rc_pay_spec',
                'ratecode.rc_pay_rate',
                'ratecode.rc_inv_vattype',
                'ratecode.rc_inv_vatonly',
                'ratecode.rc_inv_factor',
                'ratecode.rc_inv_rate',
                'ratecode.rc_factor_code',
                'ratecode.rc_hrs_day'
            ],
        },
    }
},
'/bookings' => {
    get => {
        summary => 'Returns bookings',
        operationId => 'GetBookings',
        responses => {
            bookings => [ 'bookings.oa_booking_no' ],
        },
    },
},
'/booking/{bookingNo}/{workweekEndDate}' => {
    'get' => {
        summary => 'Returns rate codes, limits, pay rates for a booking, any existing timesheet detail record for that booking and workwkend',
        operationId => 'GetBookingTimesheets',
        parameters => { bookingNo       => { sql => 'bookings.oa_booking_no', desc => "Booking Number" },
                        workweekEndDate => { sql => 'timesheet.th_paywkend', desc => "Date of week end" },
                        },
        responses => {
            bookingtimesheets => [ 'timesheet.th_timesheet_no' ],
        },
    },
},
},
};
