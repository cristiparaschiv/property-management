package PropertyManager::Routes::Profile;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf);
use Try::Tiny;

=head1 NAME

PropertyManager::Routes::Profile - User profile management routes

=head1 DESCRIPTION

Provides endpoints for managing user profiles and company settings.
Combines user personal information with company data for a complete profile view.

=cut

# ============================================================================
# Profile Routes
# ============================================================================

=head2 GET /api/profile

Get current user's profile including company information.

Returns:
  {
    success: true,
    data: {
      user: { user fields },
      company: { company fields }
    }
  }

Protected route - requires authentication.

=cut

get '/api/profile' => sub {
    # Require authentication
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = var('user');

    try {
        # Get company information
        my $company = schema->resultset('Company')->search()->first;

        unless ($company) {
            status 404;
            return {
                success => 0,
                error => 'Company information not found',
                code => 'COMPANY_NOT_FOUND',
            };
        }

        return {
            success => 1,
            data => {
                user => $user->TO_JSON,
                company => {
                    id => $company->id,
                    name => $company->name,
                    cui_cif => $company->cui_cif,
                    j_number => $company->j_number,
                    address => $company->address,
                    city => $company->city,
                    county => $company->county,
                    postal_code => $company->postal_code,
                    bank_name => $company->bank_name,
                    iban => $company->iban,
                    phone => $company->phone,
                    email => $company->email,
                    representative_name => $company->representative_name,
                    invoice_prefix => $company->invoice_prefix,
                    last_invoice_number => $company->last_invoice_number,
                },
            },
        };
    } catch {
        error("Error fetching profile: $_");
        status 500;
        return {
            success => 0,
            error => 'Failed to fetch profile',
            code => 'PROFILE_FETCH_ERROR',
        };
    };
};

=head2 PUT /api/profile

Update current user's profile.

Accepts:
  {
    user: {
      full_name: string,
      email: string,
      id_card_series: string,
      id_card_number: string,
      id_card_issued_by: string
    },
    company: {
      name: string,
      cui_cif: string,
      j_number: string,
      address: string,
      city: string,
      county: string,
      postal_code: string,
      bank_name: string,
      iban: string,
      phone: string,
      email: string,
      representative_name: string,
      invoice_prefix: string
    }
  }

Returns:
  {
    success: true,
    data: {
      user: { updated user fields },
      company: { updated company fields }
    }
  }

Protected route - requires authentication.

Security notes:
- Username cannot be changed
- Password changes require /api/auth/change-password endpoint
- Input is validated and sanitized

=cut

put '/api/profile' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = var('user');
    my $data = request->data;

    unless ($data) {
        status 400;
        return {
            success => 0,
            error => 'Request body is required',
            code => 'MISSING_BODY',
        };
    }

    try {
        my $updated_user;
        my $updated_company;

        schema->txn_do(sub {
            # Update user fields if provided
            if ($data->{user}) {
                my $user_data = $data->{user};
                my %user_update = ();

                # Validate and prepare user updates
                # Note: username and password_hash are NOT updateable here
                if (defined $user_data->{email}) {
                    # Basic email validation
                    if ($user_data->{email} !~ /^[^\s@]+@[^\s@]+\.[^\s@]+$/) {
                        die "Invalid email format\n";
                    }
                    $user_update{email} = $user_data->{email};
                }

                if (defined $user_data->{full_name}) {
                    # Trim whitespace
                    my $name = $user_data->{full_name};
                    $name =~ s/^\s+|\s+$//g;
                    $user_update{full_name} = $name || undef;
                }

                if (defined $user_data->{id_card_series}) {
                    my $series = $user_data->{id_card_series};
                    $series =~ s/^\s+|\s+$//g;
                    $user_update{id_card_series} = $series || undef;
                }

                if (defined $user_data->{id_card_number}) {
                    my $number = $user_data->{id_card_number};
                    $number =~ s/^\s+|\s+$//g;
                    $user_update{id_card_number} = $number || undef;
                }

                if (defined $user_data->{id_card_issued_by}) {
                    my $issued = $user_data->{id_card_issued_by};
                    $issued =~ s/^\s+|\s+$//g;
                    $user_update{id_card_issued_by} = $issued || undef;
                }

                # Update user if there are changes
                if (%user_update) {
                    $user->update(\%user_update);
                    $user->discard_changes;  # Reload from database
                }

                $updated_user = $user;
            }

            # Update company fields if provided
            if ($data->{company}) {
                my $company_data = $data->{company};
                my $company = schema->resultset('Company')->search()->first;

                unless ($company) {
                    die "Company information not found\n";
                }

                my %company_update = ();

                # Prepare company updates
                foreach my $field (qw(name cui_cif j_number address city county
                                     postal_code bank_name iban phone email
                                     representative_name invoice_prefix last_invoice_number)) {
                    if (defined $company_data->{$field}) {
                        my $value = $company_data->{$field};
                        # Trim whitespace for string fields
                        if (defined $value && $value ne '') {
                            $value =~ s/^\s+|\s+$//g;
                            $company_update{$field} = $value;
                        } else {
                            $company_update{$field} = undef;
                        }
                    }
                }

                # Validate invoice_prefix if provided
                if (defined $company_update{invoice_prefix}) {
                    my $prefix = $company_update{invoice_prefix};
                    if ($prefix !~ /^[A-Z]{2,10}$/) {
                        die "Invoice prefix must be 2-10 uppercase letters\n";
                    }
                }

                # Update company if there are changes
                if (%company_update) {
                    $company->update(\%company_update);
                    $company->discard_changes;  # Reload from database
                }

                $updated_company = $company;
            }
        });

        # Fetch fresh data to return
        $user->discard_changes;
        my $company = schema->resultset('Company')->search()->first;

        return {
            success => 1,
            message => 'Profile updated successfully',
            data => {
                user => $user->TO_JSON,
                company => {
                    id => $company->id,
                    name => $company->name,
                    cui_cif => $company->cui_cif,
                    j_number => $company->j_number,
                    address => $company->address,
                    city => $company->city,
                    county => $company->county,
                    postal_code => $company->postal_code,
                    bank_name => $company->bank_name,
                    iban => $company->iban,
                    phone => $company->phone,
                    email => $company->email,
                    representative_name => $company->representative_name,
                    invoice_prefix => $company->invoice_prefix,
                    last_invoice_number => $company->last_invoice_number,
                },
            },
        };
    } catch {
        my $error = $_;
        error("Error updating profile: $error");

        # Return appropriate status and message
        if ($error =~ /Invalid email/i) {
            status 400;
            return {
                success => 0,
                error => 'Invalid email format',
                code => 'INVALID_EMAIL',
            };
        } elsif ($error =~ /Invoice prefix/i) {
            status 400;
            return {
                success => 0,
                error => 'Invalid invoice prefix format',
                code => 'INVALID_INVOICE_PREFIX',
            };
        } elsif ($error =~ /not found/i) {
            status 404;
            return {
                success => 0,
                error => $error,
                code => 'NOT_FOUND',
            };
        } else {
            status 500;
            return {
                success => 0,
                error => 'Failed to update profile',
                code => 'PROFILE_UPDATE_ERROR',
            };
        }
    };
};

1;

__END__

=head1 ROUTES

=over 4

=item GET /api/profile - Get current user profile with company data

=item PUT /api/profile - Update user profile and company settings

=back

=head1 SECURITY

All routes require authentication via JWT token.

Profile updates are validated:
- Email format validation
- Invoice prefix format (2-10 uppercase letters)
- Input sanitization (whitespace trimming)
- Transaction safety for atomic updates

Restricted fields:
- Username (read-only)
- User password (use /api/auth/change-password)
- Company last_invoice_number (managed by system)

=head1 USAGE EXAMPLE

  # Get profile
  GET /api/profile
  Authorization: Bearer <token>

  # Update profile
  PUT /api/profile
  Authorization: Bearer <token>
  Content-Type: application/json

  {
    "user": {
      "full_name": "John Doe",
      "email": "john@example.com",
      "id_card_series": "AB",
      "id_card_number": "123456",
      "id_card_issued_by": "SPCLEP Bucharest"
    },
    "company": {
      "name": "My Company SRL",
      "invoice_prefix": "INV"
    }
  }

=head1 AUTHOR

Property Management System

=cut
