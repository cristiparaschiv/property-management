package PropertyManager::Routes::ActivityLogs;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use Dancer2::Plugin::DBIC;
use PropertyManager::Routes::Auth qw(require_auth get_current_user);
use Try::Tiny;
use JSON;

prefix '/api/activity-logs';

# GET /api/activity-logs - List activity logs
get '' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $limit = query_parameters->get('limit') || 50;
    my $offset = query_parameters->get('offset') || 0;
    my $entity_type = query_parameters->get('entity_type');
    my $action_type = query_parameters->get('action_type');

    my $search = {};
    $search->{entity_type} = $entity_type if $entity_type;
    $search->{action_type} = $action_type if $action_type;

    my @logs = schema->resultset('ActivityLog')->search($search, {
        order_by => { -desc => 'me.created_at' },
        rows => $limit,
        offset => $offset,
        prefetch => 'user',
    })->all;

    my @data = map {
        my %log = $_->get_columns;
        $log{user_name} = $_->user ? $_->user->full_name : 'System';
        if ($log{metadata}) {
            try {
                $log{metadata} = decode_json($log{metadata});
            };
        }
        \%log;
    } @logs;

    my $total = schema->resultset('ActivityLog')->search($search)->count;

    return {
        success => 1,
        data => {
            logs => \@data,
            total => $total,
            limit => $limit,
            offset => $offset,
        }
    };
};

# GET /api/activity-logs/recent - Get recent activity for dashboard
get '/recent' => sub {
    my $auth_error = require_auth();
    return $auth_error if $auth_error;

    my $limit = query_parameters->get('limit') || 10;

    my @logs = schema->resultset('ActivityLog')->search({}, {
        order_by => { -desc => 'me.created_at' },
        rows => $limit,
        prefetch => 'user',
    })->all;

    my @data = map {
        my %log = $_->get_columns;
        $log{user_name} = $_->user ? $_->user->full_name : 'System';
        if ($log{metadata}) {
            try {
                $log{metadata} = decode_json($log{metadata});
            };
        }
        \%log;
    } @logs;

    return { success => 1, data => \@data };
};

1;
