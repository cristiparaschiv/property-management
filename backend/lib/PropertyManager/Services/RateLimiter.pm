package PropertyManager::Services::RateLimiter;

use strict;
use warnings;
use Try::Tiny;
use DateTime;

=head1 NAME

PropertyManager::Services::RateLimiter - Rate limiting for login attempts

=head1 SYNOPSIS

  use PropertyManager::Services::RateLimiter;

  my $limiter = PropertyManager::Services::RateLimiter->new(
      schema => $schema,
      config => $config,
  );

  # Check if IP is rate limited
  if ($limiter->is_rate_limited($ip)) {
      # Return 429 Too Many Requests
  }

  # Record failed login attempt
  $limiter->record_failed_attempt($ip);

  # Clear attempts on successful login
  $limiter->clear_attempts($ip);

=cut

sub new {
    my ($class, %args) = @_;

    die "schema is required" unless $args{schema};
    die "config is required" unless $args{config};

    return bless \%args, $class;
}

=head2 is_rate_limited

Check if an IP address is rate limited.
Returns 1 if rate limited, 0 otherwise.

=cut

sub is_rate_limited {
    my ($self, $ip_address) = @_;

    return 0 unless $ip_address;

    my $max_attempts = $self->{config}{app}{max_login_attempts} || 5;
    my $window_seconds = $self->{config}{app}{lockout_duration} || 900;  # 15 min default

    my $window_start = DateTime->now->subtract(seconds => $window_seconds);

    my $attempt_count = $self->{schema}->resultset('LoginAttempt')->search({
        ip_address => $ip_address,
        is_successful => 0,
        created_at => { '>=' => $window_start },
    })->count;

    return $attempt_count >= $max_attempts ? 1 : 0;
}

=head2 get_lockout_info

Get information about the rate limit for an IP.
Returns hashref with:
  - is_locked: boolean
  - attempts: current failed attempt count
  - max_attempts: max allowed attempts
  - lockout_remaining: seconds until lockout expires (if locked)

=cut

sub get_lockout_info {
    my ($self, $ip_address) = @_;

    return { is_locked => 0, attempts => 0 } unless $ip_address;

    my $max_attempts = $self->{config}{app}{max_login_attempts} || 5;
    my $window_seconds = $self->{config}{app}{lockout_duration} || 900;

    my $window_start = DateTime->now->subtract(seconds => $window_seconds);

    my @attempts = $self->{schema}->resultset('LoginAttempt')->search({
        ip_address => $ip_address,
        is_successful => 0,
        created_at => { '>=' => $window_start },
    }, {
        order_by => { -asc => 'created_at' }
    })->all;

    my $attempt_count = scalar @attempts;
    my $is_locked = $attempt_count >= $max_attempts;
    my $lockout_remaining = 0;

    if ($is_locked && @attempts) {
        # Calculate when lockout expires based on first attempt in window
        my $first_attempt = $attempts[0]->created_at;
        my $lockout_expires = $first_attempt->add(seconds => $window_seconds);
        $lockout_remaining = $lockout_expires->epoch - time();
        $lockout_remaining = 0 if $lockout_remaining < 0;
    }

    return {
        is_locked => $is_locked,
        attempts => $attempt_count,
        max_attempts => $max_attempts,
        lockout_remaining => $lockout_remaining,
    };
}

=head2 record_failed_attempt

Record a failed login attempt for an IP address.

=cut

sub record_failed_attempt {
    my ($self, $ip_address, $username) = @_;

    return unless $ip_address;

    try {
        $self->{schema}->resultset('LoginAttempt')->create({
            ip_address => $ip_address,
            username => $username,
            is_successful => 0,
        });
    } catch {
        warn "Failed to record login attempt: $_";
    };
}

=head2 record_successful_attempt

Record a successful login attempt (for auditing).

=cut

sub record_successful_attempt {
    my ($self, $ip_address, $username) = @_;

    return unless $ip_address;

    try {
        $self->{schema}->resultset('LoginAttempt')->create({
            ip_address => $ip_address,
            username => $username,
            is_successful => 1,
        });
    } catch {
        warn "Failed to record successful login: $_";
    };
}

=head2 clear_attempts

Clear failed login attempts for an IP address.
Call this after a successful login.

=cut

sub clear_attempts {
    my ($self, $ip_address) = @_;

    return unless $ip_address;

    try {
        $self->{schema}->resultset('LoginAttempt')->search({
            ip_address => $ip_address,
            is_successful => 0,
        })->delete;
    } catch {
        warn "Failed to clear login attempts: $_";
    };
}

=head2 cleanup_old_attempts

Remove old login attempts from the database.
Should be called periodically (e.g., daily cron job).

=cut

sub cleanup_old_attempts {
    my ($self, $days_to_keep) = @_;

    $days_to_keep ||= 30;

    my $cutoff = DateTime->now->subtract(days => $days_to_keep);

    try {
        my $deleted = $self->{schema}->resultset('LoginAttempt')->search({
            created_at => { '<' => $cutoff },
        })->delete;
        return $deleted;
    } catch {
        warn "Failed to cleanup old login attempts: $_";
        return 0;
    };
}

1;

__END__

=head1 DESCRIPTION

Rate limiting service for protecting login endpoint against brute force attacks.

Uses database storage to track failed login attempts by IP address.
Works across multiple application workers/processes.

=head1 CONFIGURATION

Reads from config:

  app:
    max_login_attempts: 5      # Max failed attempts before lockout
    lockout_duration: 900      # Lockout window in seconds (15 min)

=head1 DATABASE TABLE

Requires a login_attempts table:

  CREATE TABLE login_attempts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      ip_address VARCHAR(45) NOT NULL,
      username VARCHAR(255),
      is_successful BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_ip_created (ip_address, created_at)
  );

=head1 AUTHOR

Property Management System

=cut
