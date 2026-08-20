#!/usr/bin/env perl
#
# Loan arithmetic. The fixture is the original spreadsheet's own totals:
# Imprumutat 236.918, Recuperat 120.000, sold 116.918, servicii 13.300 at
# the date the sheet was written, net 103.618.

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../../lib";

use_ok('PropertyManager::Services::Loan');

my $svc = 'PropertyManager::Services::Loan';

my @ENTRIES = (
    { entry_date => '2024-09-20', label => 'FF CPPI24 0055', amount => '-125000.00' },
    { entry_date => '2024-09-26', label => 'FF CPPI24 0059', amount => '-19653.00' },
    { entry_date => '2024-10-16', label => 'FF CPPI24 0060', amount => '-35365.00' },
    { entry_date => '2024-10-28', label => 'FF CPPI24 0061', amount => '-11900.00' },
    { entry_date => '2024-11-28', label => 'FF CPPI24 0062', amount => '-45000.00' },
    { entry_date => '2025-05-06', label => 'Cash',            amount => '20000.00' },
    { entry_date => '2025-05-06', label => 'Revolut',         amount => '5000.00' },
    { entry_date => '2025-08-01', label => 'Revolut',         amount => '15000.00' },
    { entry_date => '2025-10-08', label => 'Cash',            amount => '10000.00' },
    { entry_date => '2025-12-29', label => 'Cash',            amount => '5000.00' },
    { entry_date => '2026-03-20', label => 'Cash',            amount => '10000.00' },
    { entry_date => '2026-04-06', label => 'Cash',            amount => '10000.00' },
    { entry_date => '2026-05-06', label => 'Cash',            amount => '10000.00' },
    { entry_date => '2026-05-18', label => 'Cash',            amount => '10000.00' },
    { entry_date => '2026-06-18', label => 'Cash',            amount => '15000.00' },
    { entry_date => '2026-07-03', label => 'Cash',            amount => '10000.00' },
);

my %LOAN = (offset_rate => '700.00', offset_start => '2025-01-01', currency => 'RON');

# -- month counting ---------------------------------------------------------

subtest 'months_accrued counts both ends' => sub {
    is($svc->months_accrued('2025-01-01', '2026-07-31'), 19, 'the sheet-s hardcoded 19');
    is($svc->months_accrued('2025-01-01', '2026-08-20'), 20, '...which goes stale');
    is($svc->months_accrued('2025-01-01', '2025-01-31'), 1,  'first month counts');
    is($svc->months_accrued('2025-01-01', '2024-12-01'), 0,  'never negative');
    is($svc->months_accrued(undef,        '2026-08-20'), 0,  'no start date, no accrual');
};

# -- totals -----------------------------------------------------------------

subtest 'totals match the spreadsheet' => sub {
    my $s = $svc->summarise(\%LOAN, \@ENTRIES, '2026-07-31');
    is($s->{lent},        '236918.00', 'imprumutat');
    is($s->{repaid},      '120000.00', 'recuperat');
    is($s->{outstanding}, '116918.00', 'sold imprumut');
    is($s->{offset_total}, '13300.00', 'servicii contabile');
    is($s->{offset_months}, 19,        'luni');
    is($s->{net_owed},    '103618.00', 'rest de recuperat');
};

subtest 'the offset keeps accruing past the sheet' => sub {
    my $s = $svc->summarise(\%LOAN, \@ENTRIES, '2026-08-20');
    is($s->{offset_months}, 20,        'august is the 20th month');
    is($s->{offset_total}, '14000.00', '20 x 700');
    is($s->{net_owed},    '102918.00', 'net moves with it');
};

subtest 'a zero rate disables the offset' => sub {
    my $s = $svc->summarise({ %LOAN, offset_rate => '0.00' }, \@ENTRIES, '2026-08-20');
    is($s->{offset_total}, '0.00',     'nothing accrues');
    is($s->{net_owed},    '116918.00', 'net is the raw balance');
};

subtest 'money keeps two decimals and does not drift' => sub {
    my @thirds = map { { entry_date => '2025-01-0' . $_, label => 'x',
                         amount => '-0.10' } } (1 .. 3);
    my $s = $svc->summarise({ offset_rate => 0 }, \@thirds, '2025-02-01');
    is($s->{outstanding}, '0.30', 'three tenths sum exactly');
};

# -- the balance curve ------------------------------------------------------

subtest 'balance series' => sub {
    my $series = $svc->balance_series(\@ENTRIES);
    is(scalar @$series, 16, 'one point per entry');
    is($series->[0]{balance},  '125000.00', 'starts at the first advance');
    is($series->[-1]{balance}, '116918.00', 'ends at the outstanding balance');

    my ($peak) = sort { $b->{balance} <=> $a->{balance} } @$series;
    is($peak->{balance}, '236918.00', 'peaks when lending stops');
    is($peak->{entry_date}, '2024-11-28', 'on the last advance');

    my @dates = map { $_->{entry_date} } @$series;
    is_deeply(\@dates, [sort @dates], 'chronological');

    my @same_day = grep { $_->{entry_date} eq '2025-05-06' } @$series;
    is(scalar @same_day, 2, 'both entries on 6 May appear');
    is($same_day[-1]{balance}, '211918.00', 'and both are applied');
};

subtest 'series survives unsorted input' => sub {
    my @shuffled = reverse @ENTRIES;
    my $series = $svc->balance_series(\@shuffled);
    is($series->[-1]{balance}, '116918.00', 'same end balance');
};

subtest 'an empty ledger is not an error' => sub {
    my $s = $svc->summarise(\%LOAN, [], '2026-08-20');
    is($s->{outstanding}, '0.00', 'nothing owed');
    is_deeply($svc->balance_series([]), [], 'no points');
    is($s->{projected_payoff}, undef, 'nothing to project');
};

# -- pace and projection ----------------------------------------------------

subtest 'pace and projection' => sub {
    my $s = $svc->summarise(\%LOAN, \@ENTRIES, '2026-08-20');
    cmp_ok($s->{monthly_pace}, '>', 6000, 'pace above 6k');
    cmp_ok($s->{monthly_pace}, '<', 9000, 'pace below 9k');
    like($s->{projected_payoff}, qr/^\d{4}-\d{2}-\d{2}$/, 'an ISO date');
    cmp_ok($s->{projected_payoff}, 'gt', '2026-08-20', 'in the future');
};

subtest 'a settled loan projects nothing' => sub {
    my $s = $svc->summarise({ offset_rate => 0 }, [
        { entry_date => '2024-09-20', label => 'a', amount => '-1000.00' },
        { entry_date => '2025-01-05', label => 'b', amount => '1000.00' },
    ], '2026-08-20');
    is($s->{outstanding}, '0.00', 'paid off');
    is($s->{projected_payoff}, undef, 'no projection');
};

subtest 'no repayments means no projection' => sub {
    my $s = $svc->summarise({ offset_rate => 0 },
        [{ entry_date => '2024-09-20', label => 'a', amount => '-1000.00' }],
        '2026-08-20');
    is($s->{projected_payoff}, undef, 'cannot extrapolate from nothing');
};

done_testing();
