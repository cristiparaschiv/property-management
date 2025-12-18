package PropertyManager::Routes::Notifications;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth require_csrf get_current_user);
use Try::Tiny;
use DateTime;

prefix '/api/notifications';

# GET /api/notifications - List notifications for current user
get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = get_current_user();
    my $include_read = query_parameters->get('include_read') // 0;
    my $limit = query_parameters->get('limit') || 20;

    my $search = {
        is_dismissed => 0,
        -or => [
            { user_id => $user->{id} },
            { user_id => undef },  # Global notifications
        ],
    };

    $search->{is_read} = 0 unless $include_read;

    my @notifications = schema->resultset('Notification')->search($search, {
        order_by => { -desc => 'created_at' },
        rows => $limit,
    })->all;

    my @data = map { { $_->get_columns } } @notifications;

    return { success => 1, data => \@data };
};

# GET /api/notifications/count - Get unread notification count
get '/count' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $user = get_current_user();

    my $count = schema->resultset('Notification')->search({
        is_read => 0,
        is_dismissed => 0,
        -or => [
            { user_id => $user->{id} },
            { user_id => undef },
        ],
    })->count;

    return { success => 1, data => { count => $count } };
};

# GET /api/notifications/check - Check for new notifications (invoice due dates, unpaid invoices)
get '/check' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my @created_notifications;

    # Check for invoices due in 3 days
    my $three_days = DateTime->now->add(days => 3)->ymd;
    my $today = DateTime->now->ymd;

    my @due_soon = schema->resultset('ReceivedInvoice')->search({
        is_paid => 0,
        due_date => { '>' => $today, '<=' => $three_days },
    })->all;

    foreach my $invoice (@due_soon) {
        # Check if notification already exists
        my $exists = schema->resultset('Notification')->search({
            category => 'due_soon',
            entity_type => 'received_invoice',
            entity_id => $invoice->id,
            is_dismissed => 0,
        })->count;

        unless ($exists) {
            my $notification = schema->resultset('Notification')->create({
                type => 'warning',
                category => 'due_soon',
                title => 'Factură scadentă curând',
                message => sprintf('Factura %s de la %s scade pe %s',
                    $invoice->invoice_number,
                    $invoice->provider ? $invoice->provider->name : 'Unknown',
                    $invoice->due_date),
                entity_type => 'received_invoice',
                entity_id => $invoice->id,
                link => '/received-invoices',
            });
            push @created_notifications, { $notification->get_columns };
        }
    }

    # Check for overdue invoices
    my @overdue = schema->resultset('ReceivedInvoice')->search({
        is_paid => 0,
        due_date => { '<' => $today },
    })->all;

    foreach my $invoice (@overdue) {
        my $exists = schema->resultset('Notification')->search({
            category => 'overdue',
            entity_type => 'received_invoice',
            entity_id => $invoice->id,
            is_dismissed => 0,
        })->count;

        unless ($exists) {
            my $notification = schema->resultset('Notification')->create({
                type => 'error',
                category => 'overdue',
                title => 'Factură restantă',
                message => sprintf('Factura %s de la %s este restantă (scadentă %s)',
                    $invoice->invoice_number,
                    $invoice->provider ? $invoice->provider->name : 'Unknown',
                    $invoice->due_date),
                entity_type => 'received_invoice',
                entity_id => $invoice->id,
                link => '/received-invoices',
            });
            push @created_notifications, { $notification->get_columns };
        }
    }

    # Check for unpaid issued invoices
    my @unpaid_issued = schema->resultset('Invoice')->search({
        is_paid => 0,
        due_date => { '<' => $today },
    })->all;

    foreach my $invoice (@unpaid_issued) {
        my $exists = schema->resultset('Notification')->search({
            category => 'unpaid_issued',
            entity_type => 'invoice',
            entity_id => $invoice->id,
            is_dismissed => 0,
        })->count;

        unless ($exists) {
            my $notification = schema->resultset('Notification')->create({
                type => 'warning',
                category => 'unpaid_issued',
                title => 'Factură emisă neplătită',
                message => sprintf('Factura %s către %s nu a fost încă plătită',
                    $invoice->invoice_number,
                    $invoice->tenant ? $invoice->tenant->name : ($invoice->client_name || 'Client')),
                entity_type => 'invoice',
                entity_id => $invoice->id,
                link => '/invoices',
            });
            push @created_notifications, { $notification->get_columns };
        }
    }

    return {
        success => 1,
        data => {
            created => scalar @created_notifications,
            notifications => \@created_notifications,
        }
    };
};

# PUT /api/notifications/:id/read - Mark notification as read
put '/:id/read' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $notification = schema->resultset('Notification')->find(route_parameters->get('id'));
    unless ($notification) {
        status 404;
        return { success => 0, error => 'Notification not found' };
    }

    $notification->update({
        is_read => 1,
        read_at => \'NOW()',
    });

    return { success => 1, message => 'Notification marked as read' };
};

# PUT /api/notifications/read-all - Mark all notifications as read
put '/read-all' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $user = get_current_user();

    schema->resultset('Notification')->search({
        is_read => 0,
        -or => [
            { user_id => $user->{id} },
            { user_id => undef },
        ],
    })->update({
        is_read => 1,
        read_at => \'NOW()',
    });

    return { success => 1, message => 'All notifications marked as read' };
};

# DELETE /api/notifications/:id - Dismiss notification
del '/:id' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $csrf_error = require_csrf();
    return $csrf_error if $csrf_error;

    my $notification = schema->resultset('Notification')->find(route_parameters->get('id'));
    unless ($notification) {
        status 404;
        return { success => 0, error => 'Notification not found' };
    }

    $notification->update({ is_dismissed => 1 });

    return { success => 1, message => 'Notification dismissed' };
};

1;
